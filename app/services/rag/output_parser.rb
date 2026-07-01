# frozen_string_literal: true

module Rag
  # Normalizes the model's raw JSON into a stable, type-safe structure regardless
  # of prompt version. It does NOT decide trust -- grounding/citation enforcement
  # happens next in Guardrails. Unknown citation refs (ids the model invented that
  # are not in the retrieved evidence) are stripped here.
  class OutputParser
    def self.call(...) = new(...).call

    def initialize(context)
      @context = context
    end

    def call
      started = now_ms
      raw = @context.parsed || {}
      valid_refs = @context.evidence.map { |e| e[:ref] }.to_set

      normalized = {
        "headline" => raw["headline"].to_s.strip,
        "sections" => normalize_sections(raw["sections"], valid_refs),
        "flags" => Array(raw["flags"]).map(&:to_s).reject(&:blank?),
        "insufficient_evidence" => truthy?(raw["insufficient_evidence"])
      }
      @context.parsed = normalized

      dropped = count_dropped_citations(raw["sections"], valid_refs)
      @context.trace(
        step: "output_parser",
        input: { sections: Array(raw["sections"]).size },
        output: { sections: normalized["sections"].size,
                  hallucinated_citations_dropped: dropped },
        latency_ms: now_ms - started
      )
      @context
    end

    private

    def normalize_sections(sections, valid_refs)
      Array(sections).filter_map do |section|
        next unless section.is_a?(Hash)

        body = section["body"].to_s.strip
        next if body.blank?

        {
          "title" => section["title"].to_s.strip.presence || "Summary",
          "body" => body,
          "citations" => Array(section["citations"]).map(&:to_s).select { |r| valid_refs.include?(r) }.uniq
        }
      end
    end

    def count_dropped_citations(sections, valid_refs)
      Array(sections).sum do |section|
        next 0 unless section.is_a?(Hash)

        Array(section["citations"]).map(&:to_s).count { |r| !valid_refs.include?(r) }
      end
    end

    def truthy?(value)
      [true, "true", 1, "1"].include?(value)
    end

    def now_ms
      Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
    end
  end
end
