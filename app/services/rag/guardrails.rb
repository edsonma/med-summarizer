# frozen_string_literal: true

module Rag
  # The safety layer. Two responsibilities:
  #
  #   screen_input  -> detects prompt-injection / jailbreak attempts in the
  #                    clinician's *query* and blocks obvious overrides. (Injected
  #                    instructions inside document text are neutralised separately
  #                    by the hardened v2 prompt.)
  #
  #   enforce       -> the post-generation trust gate:
  #                    * 0 retrieved chunks  -> "no_evidence" fallback (no LLM guess)
  #                    * model self-reports insufficient evidence -> "no_evidence"
  #                    * (v2) every kept section must carry a valid citation;
  #                      ungrounded sections are dropped to kill hallucinations
  #                    * computes a confidence score and appends a clinical
  #                      disclaimer + the citation list.
  class Guardrails
    DISCLAIMER = "AI-generated summary for licensed clinician review only. Not a " \
                 "diagnostic device. Verify every value against the source documents."

    INJECTION_PATTERNS = [
      /ignore (all |previous |prior )?(instructions|prompts)/i,
      /disregard (the )?(system|above|previous)/i,
      /reveal (your )?(system )?prompt/i,
      /you are now/i,
      /act as (an?|the)?\s*(dan|jailbreak|unrestricted)/i,
      /print .*api[_ ]?key/i
    ].freeze

    def self.screen_input(context)
      started = now_ms
      hit = INJECTION_PATTERNS.find { |re| context.query.match?(re) }
      if hit
        context.status = "blocked"
        context.confidence = 0.0
        context.parsed = blocked_payload
      end
      context.trace(
        step: "guardrails_input",
        input: { query: context.query },
        output: { blocked: hit ? true : false, pattern: hit&.source },
        latency_ms: now_ms - started,
        status: hit ? "blocked" : "ok"
      )
      context
    end

    def self.enforce(context)
      started = now_ms
      status = "ok"

      if context.evidence.blank?
        status = "no_evidence"
        apply_no_evidence(context)
      elsif context.parsed["insufficient_evidence"]
        status = "no_evidence"
        apply_no_evidence(context)
      else
        enforce_grounding(context)
        status = "no_evidence" if context.parsed["sections"].blank?
        finalize_grounded(context)
      end

      context.status = status
      context.confidence ||= confidence_for(context, status)

      context.trace(
        step: "guardrails_output",
        input: { evidence: context.evidence.size, sections_in: context.parsed["sections"].size },
        output: { status: status, confidence: context.confidence,
                  citations: Array(context.parsed["citations"]).size },
        latency_ms: now_ms - started,
        status: status
      )
      context
    end

    # ---- helpers -----------------------------------------------------------

    def self.enforce_grounding(context)
      # v1 (baseline) intentionally has no citations; skip so its hallucinations
      # are visible in evaluation. v2 requires a valid citation per section.
      return if context.prompt_version == "v1"

      grounded = context.parsed["sections"].select { |s| Array(s["citations"]).any? }
      context.parsed["sections"] = grounded
    end

    def self.finalize_grounded(context)
      cited_refs = context.parsed["sections"].flat_map { |s| Array(s["citations"]) }.uniq
      context.parsed["citations"] = build_citations(context, cited_refs)
      context.parsed["disclaimer"] = DISCLAIMER
    end

    def self.build_citations(context, refs)
      by_ref = context.evidence.index_by { |e| e[:ref] }
      refs.filter_map do |ref|
        ev = by_ref[ref]
        next unless ev

        excerpt = (ev[:matched]&.first || ev[:content]).to_s.strip.truncate(240)
        { "ref" => ref, "doc_type" => ev[:doc_type], "document_id" => ev[:document_id], "excerpt" => excerpt }
      end
    end

    def self.apply_no_evidence(context)
      context.parsed = {
        "headline" => "Insufficient evidence to summarize",
        "sections" => [],
        "flags" => ["No sufficiently relevant documents were found for this query."],
        "citations" => [],
        "insufficient_evidence" => true,
        "disclaimer" => DISCLAIMER,
        "message" => "No matching patient documents were retrieved. Please attach " \
                     "the relevant records or refine the query, then try again."
      }
      context.confidence = 0.0
    end

    def self.blocked_payload
      {
        "headline" => "Request blocked",
        "sections" => [],
        "flags" => ["The request was blocked by the input safety filter (possible prompt injection)."],
        "citations" => [],
        "disclaimer" => DISCLAIMER
      }
    end

    # Confidence blends retrieval quality (best cosine similarity) with citation
    # coverage across the kept sections.
    def self.confidence_for(context, status)
      return 0.0 unless status == "ok"
      return 0.0 if context.evidence.blank?

      best_distance = context.evidence.map { |e| e[:distance] }.min
      similarity = [1.0 - best_distance, 0.0].max

      sections = context.parsed["sections"]
      coverage = if sections.blank?
                   0.0
                 else
                   sections.count { |s| Array(s["citations"]).any? }.to_f / sections.size
                 end

      score = context.prompt_version == "v1" ? similarity : similarity * (0.5 + 0.5 * coverage)
      score.clamp(0.0, 1.0).round(3)
    end

    def self.now_ms
      Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
    end
  end
end
