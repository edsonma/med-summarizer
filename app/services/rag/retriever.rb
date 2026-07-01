# frozen_string_literal: true

module Rag
  # Vector retrieval over CHILD chunks (small, precise) using pgvector cosine
  # distance via the `neighbor` gem. Metadata filters produced by the
  # self-querying step are applied as SQL WHERE clauses first, so the ANN search
  # only ranks the relevant subset.
  #
  # Neighbours farther than Config.max_distance are discarded: a weak match is
  # treated as "no evidence" rather than being force-fed to the LLM (a key
  # hallucination guard).
  class Retriever
    def self.call(...) = new(...).call

    def initialize(context, client: Llm::Client.new)
      @context = context
      @client = client
    end

    def call
      started = now_ms
      @context.query_embedding = @client.embed_one(@context.normalized_query)

      neighbors = search
      @context.child_neighbors = neighbors

      @context.trace(
        step: "retriever",
        input: { query: @context.normalized_query, filters: @context.filters,
                 top_k: MedSummarizer::Config.retrieval_top_k },
        output: { candidates: neighbors.size,
                  distances: neighbors.map { |n| n[:distance].round(4) } },
        latency_ms: now_ms - started,
        status: neighbors.any? ? "ok" : "no_evidence"
      )
      @context
    end

    private

    def search
      scope = DocumentChunk.children_only.where.not(embedding: nil)
      scope = scope.joins(:document)
      scope = scope.where(documents: { patient_id: @context.patient.id }) if @context.patient
      scope = apply_metadata_filters(scope)

      results = scope
                .nearest_neighbors(:embedding, @context.query_embedding, distance: "cosine")
                .limit(MedSummarizer::Config.retrieval_top_k)

      results.filter_map do |chunk|
        distance = chunk.neighbor_distance
        next if distance.nil? || distance > MedSummarizer::Config.max_distance

        { chunk: chunk, distance: distance }
      end
    end

    def apply_metadata_filters(scope)
      filters = @context.filters
      if filters[:doc_type].present?
        scope = scope.where("document_chunks.metadata->>'doc_type' = ?", filters[:doc_type])
      end
      if filters[:date_from].present?
        scope = scope.where("documents.document_date >= ?", filters[:date_from].beginning_of_day)
      end
      if filters[:date_to].present?
        scope = scope.where("documents.document_date <= ?", filters[:date_to].end_of_day)
      end
      scope
    end

    def now_ms
      Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
    end
  end
end
