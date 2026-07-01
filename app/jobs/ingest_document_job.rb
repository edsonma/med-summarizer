# frozen_string_literal: true

class IngestDocumentJob < ApplicationJob
  queue_as :default

  # Embedding calls can hit transient rate limits; retry with backoff.
  retry_on Llm::Error, wait: :polynomially_longer, attempts: 3

  def perform(document_id)
    document = Document.find(document_id)
    Ingestion::Pipeline.call(document)
  end
end
