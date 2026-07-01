# frozen_string_literal: true

module Api
  module V1
    class DocumentsController < BaseController
      # POST /api/v1/documents
      # { "document": { "patient_id": 1, "doc_type": "lab_report",
      #                 "raw_text": "...", "document_date": "2026-05-01" } }
      def create
        document = Document.new(document_params.merge(status: "pending"))
        document.save!
        IngestDocumentJob.perform_later(document.id)

        render json: {
          id: document.id,
          patient_id: document.patient_id,
          doc_type: document.doc_type,
          status: document.status
        }, status: :created
      end

      private

      def document_params
        params.require(:document).permit(:patient_id, :doc_type, :raw_text, :filename, :document_date)
      end
    end
  end
end
