# frozen_string_literal: true

class DocumentsController < ApplicationController
  def create
    @patient = Patient.find(params[:patient_id])
    document = build_document

    if document.save
      IngestDocumentJob.perform_later(document.id)
      redirect_to @patient, notice: "Document uploaded and queued for ingestion."
    else
      redirect_to @patient, alert: document.errors.full_messages.to_sentence
    end
  rescue Ingestion::TextExtractor::ExtractionError => e
    redirect_to @patient, alert: "Could not read the file: #{e.message}"
  end

  private

  def build_document
    raw_text = extracted_text
    @patient.documents.new(
      doc_type: params.dig(:document, :doc_type),
      filename: uploaded_file&.original_filename,
      raw_text: raw_text,
      document_date: params.dig(:document, :document_date).presence,
      status: "pending"
    )
  end

  # Accept either an uploaded file (PDF/text) or pasted raw text.
  def extracted_text
    if uploaded_file
      Ingestion::TextExtractor.call(uploaded_file)
    else
      params.dig(:document, :raw_text).to_s
    end
  end

  def uploaded_file
    params.dig(:document, :file)
  end
end
