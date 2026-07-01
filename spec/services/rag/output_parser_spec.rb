# frozen_string_literal: true

require "rails_helper"

RSpec.describe Rag::OutputParser do
  def context_with(parsed)
    ctx = Rag::Context.new(query: "q", prompt_version: "v2")
    ctx.evidence = [{ ref: "chunk-1", doc_type: "lab_report", content: "LDL 168" }]
    ctx.parsed = parsed
    ctx
  end

  it "strips hallucinated citation refs not present in the evidence" do
    ctx = context_with(
      "headline" => "Summary",
      "sections" => [
        { "title" => "Lipids", "body" => "LDL is elevated.", "citations" => %w[chunk-1 chunk-999] }
      ],
      "flags" => [],
      "insufficient_evidence" => false
    )

    described_class.call(ctx)

    expect(ctx.parsed["sections"].first["citations"]).to eq(["chunk-1"])
  end

  it "drops sections with an empty body" do
    ctx = context_with(
      "headline" => "Summary",
      "sections" => [{ "title" => "Empty", "body" => "  ", "citations" => ["chunk-1"] }]
    )

    described_class.call(ctx)

    expect(ctx.parsed["sections"]).to be_empty
  end
end
