# frozen_string_literal: true

# Namespace for the LLM/embedding provider integration.
module Llm
  class Error < StandardError; end

  # Raised when no API key is configured. The RAG chain converts this into a
  # safe, user-facing "unavailable" response instead of crashing.
  class NotConfiguredError < Error; end
end
