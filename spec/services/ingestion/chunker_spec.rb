# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ingestion::Chunker do
  let(:text) do
    <<~TXT
      Lipid panel results. Total cholesterol 244 mg/dL. LDL cholesterol 168 mg/dL which is high.

      Complete blood count. Hemoglobin 10.8 g/dL which is low. Platelets 265.

      Impression: hyperlipidemia and mild anemia. Recommend follow up in six weeks.
    TXT
  end

  it "produces parent chunks each containing child chunks" do
    parents = described_class.call(text, parent_tokens: 40, child_tokens: 12)

    expect(parents).to be_present
    expect(parents).to all(be_a(Ingestion::Chunker::Parent))
    expect(parents.flat_map(&:children)).to all(be_a(Ingestion::Chunker::Child))
  end

  it "keeps child chunks smaller than parent chunks on average" do
    parents = described_class.call(text, parent_tokens: 60, child_tokens: 12)
    child_sizes = parents.flat_map(&:children).map { |c| described_class.estimate_tokens(c.content) }

    expect(child_sizes.max).to be <= 60
  end

  it "assigns sequential positions" do
    parents = described_class.call(text, parent_tokens: 30, child_tokens: 10)
    expect(parents.map(&:position)).to eq((0...parents.size).to_a)
  end
end
