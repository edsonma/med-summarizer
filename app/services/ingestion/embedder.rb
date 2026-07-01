# frozen_string_literal: true

module Ingestion
  # Embeds a batch of DocumentChunk records (child chunks) in as few API calls
  # as possible, then persists the vectors. Batching keeps embedding cost and
  # latency low during ingestion.
  class Embedder
    BATCH_SIZE = 96

    def initialize(client: Llm::Client.new)
      @client = client
    end

    # chunks: Array<DocumentChunk> (expected kind == "child")
    def embed_chunks!(chunks)
      chunks.each_slice(BATCH_SIZE) do |batch|
        vectors = @client.embed(batch.map(&:content))
        batch.each_with_index do |chunk, i|
          chunk.update_column(:embedding, vectors[i])
        end
      end
    end
  end
end
