# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API::V1::Summaries", type: :request do
  let(:client) { FakeLlmClient.new }
  let(:patient) { Patient.create!(name: "John Smith", mrn: "MRN-TEST-2") }

  before do
    # Route every provider call (ingestion embeddings + chain) through the fake.
    allow(Llm::Client).to receive(:new).and_return(client)

    document = patient.documents.create!(
      doc_type: "lab_report", status: "pending", document_date: Date.new(2026, 6, 1),
      raw_text: "Diabetes panel. Hemoglobin A1c 8.4 percent high. Fasting glucose 156 high. " \
                "Impression poorly controlled type 2 diabetes."
    )
    Ingestion::Pipeline.call(document)
  end

  it "returns a grounded, cited summary as JSON" do
    post "/api/v1/summaries",
         params: { query: "Summarize the diabetes panel and A1c", patient_id: patient.id }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }

    expect(response).to have_http_status(:created)
    body = JSON.parse(response.body)
    expect(body["status"]).to eq("ok")
    expect(body.dig("content", "citations")).to be_present
    expect(body.dig("content", "sections")).to be_present
  end
end
