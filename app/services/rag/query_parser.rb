# frozen_string_literal: true

module Rag
  # Self-Querying step (advanced technique #2).
  #
  # Turns a free-text clinical question into (a) a clean semantic query used for
  # embedding and (b) structured metadata filters (doc_type, date range) that are
  # pushed down into SQL BEFORE the vector search. This narrows the candidate set
  # so retrieval is both cheaper and more precise, e.g.
  #   "what did his lipid panel show last month?"
  #     -> query: "lipid panel results"
  #     -> filters: { doc_type: "lab_report", date_from: <30d ago> }
  #
  # Degrades gracefully: if the LLM is unavailable or returns junk, we fall back
  # to the raw query with no filters (still correct, just less selective).
  class QueryParser
    SYSTEM = <<~PROMPT.freeze
      You extract structured search filters from a clinician's question about a
      patient's medical documents. Respond with a JSON object only.

      Schema:
        {
          "semantic_query": string,   // the question rephrased for semantic search, no dates/filenames
          "doc_type": one of ["lab_report","imaging_report","prescription","clinical_note"] or null,
          "date_from": "YYYY-MM-DD" or null,
          "date_to": "YYYY-MM-DD" or null
        }

      Rules:
      - Only set doc_type when the question clearly targets one document category.
      - Resolve relative dates ("last month", "this year") against TODAY provided by the user.
      - Never invent patient facts. Only parse the query text.
    PROMPT

    def self.call(...) = new(...).call

    def initialize(context, client: Llm::Client.new)
      @context = context
      @client = client
    end

    def call
      started = now_ms
      filters = parse_filters
      @context.filters = filters
      @context.normalized_query = filters[:semantic_query].presence || @context.query
      @context.trace(step: "query_parser", input: { query: @context.query },
                     output: filters, latency_ms: now_ms - started)
      @context
    end

    private

    def parse_filters
      return default_filters unless @client.configured?

      user = "TODAY is #{Date.current.iso8601}.\nQuestion: #{@context.query}"
      result = @client.chat_json(system: SYSTEM, user: user, max_tokens: 200)
      coerce(result[:data])
    rescue Llm::Error
      default_filters
    end

    def coerce(data)
      {
        semantic_query: data["semantic_query"].presence || @context.query,
        doc_type: (data["doc_type"] if Document::DOC_TYPES.include?(data["doc_type"])),
        date_from: parse_date(data["date_from"]),
        date_to: parse_date(data["date_to"])
      }
    end

    def default_filters
      { semantic_query: @context.query, doc_type: nil, date_from: nil, date_to: nil }
    end

    def parse_date(value)
      return nil if value.blank?

      Date.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end

    def now_ms
      Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
    end
  end
end
