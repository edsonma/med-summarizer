# frozen_string_literal: true

module Rag
  # The Orchestration Layer.
  #
  # Ruby has no native LangChain LCEL, so this composes the pipeline explicitly:
  #
  #   screen_input | query_parser | retriever | parent_docs | compressor
  #                | prompt | generator | output_parser | enforce
  #
  # Each stage is an independently testable callable that reads/writes the shared
  # Context. The chain persists a Summary and the full TraceEvent log for every
  # run (our LangSmith-style observability).
  class Chain
    Result = Struct.new(:summary, :context, keyword_init: true)

    def self.run(...) = new(...).run

    def initialize(query:, patient: nil, prompt_version: "v2", client: Llm::Client.new)
      @context = Context.new(query: query, patient: patient, prompt_version: prompt_version)
      @client = client
    end

    def run
      execute
    rescue Llm::NotConfiguredError => e
      apply_error("LLM provider is not configured (missing OPENAI_API_KEY): #{e.message}")
    rescue Llm::Error => e
      apply_error("The AI provider request failed: #{e.message}")
    rescue StandardError => e
      Rails.logger.error("[Rag::Chain] #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
      apply_error("Unexpected error while generating the summary: #{e.message}")
    ensure
      summary = persist!
      return Result.new(summary: summary, context: @context)
    end

    private

    def execute
      Guardrails.screen_input(@context)
      return if @context.blocked?

      QueryParser.call(@context, client: @client)
      Retriever.call(@context, client: @client)
      ParentDocumentRetriever.call(@context)
      ContextualCompressor.call(@context, client: @client)

      if @context.evidence?
        PromptBuilder.call(@context)
        Generator.call(@context, client: @client)
        OutputParser.call(@context)
      end

      Guardrails.enforce(@context)
    end

    def apply_error(message)
      @context.status = "error"
      @context.confidence = 0.0
      @context.parsed = {
        "headline" => "Unable to generate summary",
        "sections" => [],
        "flags" => [message],
        "citations" => [],
        "disclaimer" => Guardrails::DISCLAIMER
      }
      @context.trace(step: "error", input: {}, output: { message: message }, status: "error")
    end

    def persist!
      latency_ms = ((Time.current - @context.started_at) * 1000).round
      summary = Summary.create!(
        patient: @context.patient,
        query: @context.query,
        content: @context.parsed,
        model: MedSummarizer::Config.chat_model,
        prompt_version: @context.prompt_version,
        prompt_tokens: @context.prompt_tokens,
        completion_tokens: @context.completion_tokens,
        latency_ms: latency_ms,
        confidence: @context.confidence,
        status: @context.status
      )

      persist_traces!(summary)
      summary
    end

    def persist_traces!(summary)
      rows = @context.trace_events.map do |event|
        event.merge(summary_id: summary.id, created_at: Time.current, updated_at: Time.current)
      end
      TraceEvent.insert_all(rows) if rows.any?
    end
  end
end
