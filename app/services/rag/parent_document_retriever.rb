# frozen_string_literal: true

module Rag
  # Parent Document Retrieval (advanced technique #1).
  #
  # We searched small child chunks for precision; here we swap each matched child
  # for its larger PARENT chunk so the LLM sees full context (units, reference
  # ranges, the whole section) instead of an out-of-context fragment. Parents are
  # de-duplicated and keep the best (smallest) distance of their matched children.
  class ParentDocumentRetriever
    def self.call(...) = new(...).call

    def initialize(context)
      @context = context
    end

    def call
      started = now_ms
      by_parent = {}

      @context.child_neighbors.each do |neighbor|
        child = neighbor[:chunk]
        parent = child.parent || child
        key = parent.id

        by_parent[key] ||= {
          ref: parent.citation_ref,
          chunk: parent,
          content: parent.content,
          doc_type: parent.doc_type,
          document_id: parent.document_id,
          distance: neighbor[:distance],
          matched: []
        }
        by_parent[key][:distance] = [by_parent[key][:distance], neighbor[:distance]].min
        by_parent[key][:matched] << child.content
      end

      evidence = by_parent.values.sort_by { |e| e[:distance] }
      @context.evidence = evidence

      @context.trace(
        step: "parent_document_retriever",
        input: { child_matches: @context.child_neighbors.size },
        output: { parents: evidence.size, refs: evidence.map { |e| e[:ref] } },
        latency_ms: now_ms - started
      )
      @context
    end

    private

    def now_ms
      Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
    end
  end
end
