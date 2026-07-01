# frozen_string_literal: true

module Ingestion
  # Orchestrates ingestion for a single Document:
  #   extract (done at upload) -> chunk (parent/child) -> persist -> embed children.
  # Idempotent: re-running rebuilds the chunk tree from scratch.
  class Pipeline
    def self.call(...) = new(...).call

    def initialize(document, embedder: Embedder.new)
      @document = document
      @embedder = embedder
    end

    def call
      @document.mark_processing!
      parents = Chunker.call(@document.raw_text)

      child_records = []
      DocumentChunk.transaction do
        @document.chunks.delete_all
        parents.each do |parent|
          parent_record = create_chunk(kind: "parent", position: parent.position, content: parent.content)
          parent.children.each do |child|
            child_records << create_chunk(
              kind: "child",
              position: child.position,
              content: child.content,
              parent_id: parent_record.id
            )
          end
        end
      end

      @embedder.embed_chunks!(child_records)
      @document.mark_ingested!
      @document
    rescue StandardError => e
      @document.mark_failed!(e.message)
      raise
    end

    private

    def create_chunk(kind:, position:, content:, parent_id: nil)
      @document.chunks.create!(
        kind: kind,
        position: position,
        content: content,
        parent_id: parent_id,
        metadata: chunk_metadata
      )
    end

    def chunk_metadata
      {
        "doc_type" => @document.doc_type,
        "patient_id" => @document.patient_id,
        "document_id" => @document.id,
        "document_date" => @document.document_date&.iso8601
      }
    end
  end
end
