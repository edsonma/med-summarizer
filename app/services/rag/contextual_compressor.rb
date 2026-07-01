# frozen_string_literal: true

module Rag
  # Contextual Compression (advanced technique #3) -- an EmbeddingsFilter analogue.
  #
  # Parent chunks are large; sending them verbatim wastes tokens and buries the
  # signal. Here we split each parent into sentences, embed them once (a single
  # batch call), score them against the query embedding, and keep only the most
  # relevant sentences within a global token budget. This cuts prompt tokens and
  # latency while preserving the facts the model needs to cite.
  #
  # Degrades gracefully: with no API key, we fall back to length-based truncation.
  class ContextualCompressor
    TOKEN_BUDGET = 900
    MIN_SIMILARITY = 0.15

    def self.call(...) = new(...).call

    def initialize(context, client: Llm::Client.new)
      @context = context
      @client = client
    end

    def call
      return @context if @context.evidence.blank?

      started = now_ms
      before = total_tokens(@context.evidence)

      if @client.configured? && @context.query_embedding.present?
        compress_with_embeddings
      else
        truncate_fallback
      end

      after = total_tokens(@context.evidence)
      @context.trace(
        step: "contextual_compressor",
        input: { passages: @context.evidence.size, tokens_before: before },
        output: { tokens_after: after, saved: before - after },
        latency_ms: now_ms - started
      )
      @context
    end

    private

    def compress_with_embeddings
      indexed = []
      @context.evidence.each_with_index do |ev, ev_idx|
        split_sentences(ev[:content]).each do |sentence|
          indexed << { ev_idx: ev_idx, sentence: sentence }
        end
      end
      return if indexed.empty?

      vectors = @client.embed(indexed.map { |s| s[:sentence] })
      indexed.each_with_index do |item, i|
        item[:score] = cosine(@context.query_embedding, vectors[i])
      end

      selected = select_within_budget(indexed)
      rebuild_evidence(selected)
    rescue Llm::Error
      truncate_fallback
    end

    # Greedily keep the highest-scoring sentences until the token budget is hit,
    # but guarantee every passage keeps at least its single best sentence.
    def select_within_budget(indexed)
      ranked = indexed.select { |s| s[:score] >= MIN_SIMILARITY }.sort_by { |s| -s[:score] }
      best_per_passage = indexed.group_by { |s| s[:ev_idx] }
                                .transform_values { |arr| arr.max_by { |s| s[:score] } }
                                .values

      chosen = {}
      budget = TOKEN_BUDGET
      (best_per_passage + ranked).each do |item|
        key = [item[:ev_idx], item[:sentence]]
        next if chosen.key?(key)

        cost = Ingestion::Chunker.estimate_tokens(item[:sentence])
        next if budget - cost < 0 && chosen.any?

        chosen[key] = item
        budget -= cost
      end
      chosen.values
    end

    def rebuild_evidence(selected)
      grouped = selected.group_by { |s| s[:ev_idx] }
      @context.evidence.each_with_index do |ev, ev_idx|
        sentences = Array(grouped[ev_idx])
        next if sentences.empty?

        # Preserve original ordering for readability.
        ordered = split_sentences(ev[:content]).select do |sent|
          sentences.any? { |s| s[:sentence] == sent }
        end
        ev[:full_content] = ev[:content]
        ev[:content] = ordered.join(" ")
      end
    end

    def truncate_fallback
      @context.evidence.each do |ev|
        words = ev[:content].split(/\s+/)
        next if words.size <= 180

        ev[:full_content] = ev[:content]
        ev[:content] = "#{words.first(180).join(' ')} …"
      end
    end

    def split_sentences(text)
      text.to_s.split(/(?<=[.!?])\s+|\n/).map(&:strip).reject(&:empty?)
    end

    def total_tokens(evidence)
      evidence.sum { |e| Ingestion::Chunker.estimate_tokens(e[:content]) }
    end

    def cosine(a, b)
      return 0.0 if a.blank? || b.blank?

      dot = 0.0
      na = 0.0
      nb = 0.0
      a.each_with_index do |v, i|
        w = b[i].to_f
        dot += v * w
        na += v * v
        nb += w * w
      end
      denom = Math.sqrt(na) * Math.sqrt(nb)
      denom.zero? ? 0.0 : dot / denom
    end

    def now_ms
      Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
    end
  end
end
