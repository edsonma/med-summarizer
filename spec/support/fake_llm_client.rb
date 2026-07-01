# frozen_string_literal: true

# Deterministic, offline stand-in for Llm::Client used across specs so the RAG
# pipeline can be exercised end-to-end without hitting OpenAI.
#
#  * embed        -> a normalized bag-of-words vector, so cosine similarity
#                    tracks real word overlap (shared words => closer vectors).
#  * chat_json    -> for the query parser, returns empty filters; for generation,
#                    it parses the citation refs out of the prompt's <evidence>
#                    block and cites the first one, echoing a real numeric value
#                    from the evidence (so answers are genuinely grounded).
class FakeLlmClient
  def initialize(dimensions: MedSummarizer::Config.embedding_dimensions)
    @dimensions = dimensions
  end

  def configured?
    true
  end

  def embed(texts)
    Array(texts).map { |t| vectorize(t) }
  end

  def embed_one(text)
    vectorize(text)
  end

  def chat_json(system:, user:, temperature: 0.0, max_tokens: 1200)
    data = if system.include?("extract structured search filters")
             { "semantic_query" => nil, "doc_type" => nil, "date_from" => nil, "date_to" => nil }
           else
             build_summary(user)
           end
    { data: data, usage: { "prompt_tokens" => 120, "completion_tokens" => 60 }, raw: data.to_json, model: "fake-model" }
  end

  private

  def build_summary(user)
    evidence_part = user.split("<evidence>").last.to_s
    refs = evidence_part.scan(/chunk-\d+/).uniq
    number = evidence_part[/\b\d+(?:\.\d+)?\b/]
    if refs.empty?
      { "headline" => "Insufficient", "sections" => [], "flags" => [], "insufficient_evidence" => true }
    else
      body = "Key finding value #{number} noted in the record."
      {
        "headline" => "Clinical summary",
        "sections" => [{ "title" => "Findings", "body" => body, "citations" => [refs.first] }],
        "flags" => [],
        "insufficient_evidence" => false
      }
    end
  end

  def vectorize(text)
    vec = Array.new(@dimensions, 0.0)
    words = text.to_s.downcase.scan(/[a-z0-9]+/)
    words.each { |w| vec[w.hash % @dimensions] += 1.0 }
    norm = Math.sqrt(vec.sum { |v| v * v })
    norm.zero? ? vec : vec.map { |v| v / norm }
  end
end
