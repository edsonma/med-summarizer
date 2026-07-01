# frozen_string_literal: true

# Central configuration for the LLM / embedding provider and the RAG pipeline.
#
# Every tunable that affects cost, latency or safety lives here so the
# trade-offs discussed in the Technical Design Document map to a single,
# auditable place. Values can be overridden via ENV (see .env.example).
module MedSummarizer
  module Config
    module_function

    def openai_api_key
      ENV["OPENAI_API_KEY"].to_s
    end

    # Whether we have a usable key. When false the app still boots and the UI
    # works; the LLM/embedding calls raise a clear, catchable error instead.
    def llm_available?
      openai_api_key.present?
    end

    # Chat model used for summarization + query parsing.
    # gpt-4o-mini is the deliberate default (see TDD, Phase 4).
    def chat_model
      ENV.fetch("OPENAI_CHAT_MODEL", "gpt-4o-mini")
    end

    # Embedding model. text-embedding-3-small => 1536 dims, cheap, strong recall.
    def embedding_model
      ENV.fetch("OPENAI_EMBEDDING_MODEL", "text-embedding-3-small")
    end

    def embedding_dimensions
      ENV.fetch("EMBEDDING_DIMENSIONS", 1536).to_i
    end

    # Retrieval knobs (Parent Document Retrieval).
    def child_chunk_tokens
      ENV.fetch("CHILD_CHUNK_TOKENS", 120).to_i
    end

    def parent_chunk_tokens
      ENV.fetch("PARENT_CHUNK_TOKENS", 600).to_i
    end

    def retrieval_top_k
      ENV.fetch("RETRIEVAL_TOP_K", 8).to_i
    end

    # Similarity floor (cosine distance). Neighbors farther than this are
    # treated as "no evidence" to avoid grounding on irrelevant text.
    def max_distance
      ENV.fetch("RETRIEVAL_MAX_DISTANCE", 0.75).to_f
    end

    def request_timeout
      ENV.fetch("OPENAI_TIMEOUT", 60).to_i
    end
  end
end

if MedSummarizer::Config.llm_available?
  OpenAI.configure do |config|
    config.access_token = MedSummarizer::Config.openai_api_key
    config.request_timeout = MedSummarizer::Config.request_timeout
    config.log_errors = Rails.env.development?
  end
end
