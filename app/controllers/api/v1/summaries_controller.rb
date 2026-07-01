# frozen_string_literal: true

module Api
  module V1
    class SummariesController < BaseController
      # POST /api/v1/summaries
      # { "query": "...", "patient_id": 1, "prompt_version": "v2" }
      def create
        patient = params[:patient_id].present? ? Patient.find(params[:patient_id]) : nil
        result = Rag::Chain.run(
          query: params.require(:query),
          patient: patient,
          prompt_version: params.fetch(:prompt_version, "v2")
        )
        render json: serialize(result.summary), status: :created
      end

      # GET /api/v1/summaries/:id
      def show
        summary = Summary.find(params[:id])
        render json: serialize(summary, include_trace: true)
      end

      private

      def serialize(summary, include_trace: false)
        payload = {
          id: summary.id,
          patient_id: summary.patient_id,
          query: summary.query,
          status: summary.status,
          confidence: summary.confidence,
          model: summary.model,
          prompt_version: summary.prompt_version,
          tokens: { prompt: summary.prompt_tokens, completion: summary.completion_tokens },
          latency_ms: summary.latency_ms,
          content: summary.content
        }
        if include_trace
          payload[:trace] = summary.trace_events.order(:sequence).map do |e|
            { step: e.step, sequence: e.sequence, status: e.status,
              latency_ms: e.latency_ms, tokens: e.tokens, output: e.output }
          end
        end
        payload
      end
    end
  end
end
