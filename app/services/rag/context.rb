# frozen_string_literal: true

module Rag
  # Mutable state object piped through every step of the chain.
  #
  # This is our Ruby stand-in for a LangChain LCEL "Runnable" pipeline: instead
  # of `prompt | model | parser`, each step is a callable that reads and writes
  # this shared Context. Keeping state explicit (rather than hidden in closures)
  # makes the pipeline trivial to trace and test step-by-step.
  class Context
    attr_accessor :query, :patient, :prompt_version, :trace_id,
                  :normalized_query, :filters,
                  :query_embedding,
                  :child_neighbors, :evidence,
                  :messages, :llm_result,
                  :parsed, :status, :confidence,
                  :prompt_tokens, :completion_tokens, :started_at,
                  :summary, :trace_events

    def initialize(query:, patient: nil, prompt_version: "v2")
      @query = query.to_s
      @patient = patient
      @prompt_version = prompt_version
      @trace_id = SecureRandom.uuid
      @normalized_query = @query
      @filters = {}
      @child_neighbors = []
      @evidence = []
      @messages = {}
      @llm_result = {}
      @parsed = {}
      @status = "ok"
      @confidence = nil
      @prompt_tokens = 0
      @completion_tokens = 0
      @started_at = Time.current
      @trace_events = []
      @sequence = 0
    end

    def evidence?
      evidence.present?
    end

    def blocked?
      status == "blocked"
    end

    def halted?
      %w[blocked no_evidence error].include?(status)
    end

    # Records a single step for the trace log (persisted at end of run).
    def trace(step:, input:, output:, tokens: 0, latency_ms: 0, status: "ok")
      @trace_events << {
        trace_id: trace_id,
        step: step,
        sequence: (@sequence += 1),
        input: sanitize(input),
        output: sanitize(output),
        tokens: tokens,
        latency_ms: latency_ms,
        status: status
      }
    end

    def total_tokens
      prompt_tokens + completion_tokens
    end

    private

    # Keep trace payloads compact and JSON-safe.
    def sanitize(value)
      case value
      when Hash then value.transform_values { |v| sanitize(v) }
      when Array then value.map { |v| sanitize(v) }
      when String then value.truncate(2000)
      else value
      end
    end
  end
end
