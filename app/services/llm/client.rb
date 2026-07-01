# frozen_string_literal: true

module Llm
  # Thin, well-behaved wrapper around the OpenAI API (chat + embeddings).
  #
  # Everything the rest of the app needs from the provider goes through here so
  # that model choice, timeouts, retries and error normalization live in one
  # place. If no API key is configured, calls raise NotConfiguredError which the
  # chain converts into a safe "no evidence / unavailable" response rather than
  # crashing.
  class Client
    def initialize(chat_model: nil, embedding_model: nil)
      @chat_model = chat_model || MedSummarizer::Config.chat_model
      @embedding_model = embedding_model || MedSummarizer::Config.embedding_model
    end

    def configured?
      MedSummarizer::Config.llm_available?
    end

    # Returns an Array of embedding vectors (Array<Array<Float>>), one per input.
    def embed(texts)
      inputs = Array(texts)
      return [] if inputs.empty?

      raise NotConfiguredError, "OPENAI_API_KEY is not set" unless configured?

      response = with_retries do
        client.embeddings(parameters: { model: @embedding_model, input: inputs })
      end
      response.fetch("data").sort_by { |d| d["index"] }.map { |d| d.fetch("embedding") }
    rescue Faraday::Error => e
      raise Error, "Embedding request failed: #{e.message}"
    end

    def embed_one(text)
      embed([text]).first
    end

    # Sends a chat request that must return a JSON object.
    # Returns { data: Hash, usage: Hash, raw: String, model: String }.
    def chat_json(system:, user:, temperature: 0.0, max_tokens: 1200)
      raise NotConfiguredError, "OPENAI_API_KEY is not set" unless configured?

      response = with_retries do
        client.chat(parameters: {
          model: @chat_model,
          temperature: temperature,
          max_tokens: max_tokens,
          response_format: { type: "json_object" },
          messages: [
            { role: "system", content: system },
            { role: "user", content: user }
          ]
        })
      end

      raw = response.dig("choices", 0, "message", "content").to_s
      {
        data: safe_parse(raw),
        usage: response.fetch("usage", {}),
        raw: raw,
        model: @chat_model
      }
    rescue Faraday::Error => e
      raise Error, "Chat request failed: #{e.message}"
    end

    private

    def client
      @client ||= OpenAI::Client.new
    end

    def safe_parse(raw)
      JSON.parse(raw)
    rescue JSON::ParserError
      # response_format: json_object makes this rare, but never trust blindly.
      {}
    end

    # Minimal exponential backoff for transient (429/5xx) errors.
    def with_retries(max_attempts: 3)
      attempt = 0
      begin
        attempt += 1
        yield
      rescue Faraday::TooManyRequestsError, Faraday::ServerError => e
        raise if attempt >= max_attempts

        sleep(0.5 * (2**(attempt - 1)))
        retry
      end
    end
  end
end
