# frozen_string_literal: true

module Rag
  # The LLM call step: sends the built messages to gpt-4o-mini and captures the
  # raw structured JSON plus token usage. Temperature is pinned to 0 for
  # reproducibility and to reduce creative (hallucinated) output.
  class Generator
    def self.call(...) = new(...).call

    def initialize(context, client: Llm::Client.new)
      @context = context
      @client = client
    end

    def call
      started = now_ms
      result = @client.chat_json(
        system: @context.messages[:system],
        user: @context.messages[:user],
        temperature: 0.0
      )

      @context.llm_result = result
      @context.parsed = result[:data]
      @context.prompt_tokens = result[:usage]["prompt_tokens"].to_i
      @context.completion_tokens = result[:usage]["completion_tokens"].to_i

      @context.trace(
        step: "generator",
        input: { model: result[:model] },
        output: { raw: result[:raw] },
        tokens: @context.total_tokens,
        latency_ms: now_ms - started
      )
      @context
    end

    private

    def now_ms
      Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
    end
  end
end
