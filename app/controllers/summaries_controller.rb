# frozen_string_literal: true

class SummariesController < ApplicationController
  def show
    @summary = Summary.find(params[:id])
    @trace_events = @summary.trace_events.order(:sequence)
  end

  def create
    patient = params[:patient_id].present? ? Patient.find(params[:patient_id]) : nil
    result = Rag::Chain.run(
      query: params.dig(:summary, :query).to_s,
      patient: patient,
      prompt_version: params.dig(:summary, :prompt_version).presence || "v2"
    )
    redirect_to summary_path(result.summary)
  end
end
