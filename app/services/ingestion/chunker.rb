# frozen_string_literal: true

module Ingestion
  # Produces the two-tier chunk hierarchy that powers Parent Document Retrieval:
  #
  #   * PARENT chunks are large (~600 tokens) and give the LLM enough surrounding
  #     context to reason correctly (e.g. the whole "Lipid Panel" section).
  #   * CHILD chunks are small (~120 tokens) and are what we embed + search, so
  #     retrieval is precise (a single abnormal value matches sharply).
  #
  # At query time we search children but hand the LLM their parents.
  class Chunker
    Parent = Struct.new(:position, :content, :children, keyword_init: true)
    Child  = Struct.new(:position, :content, keyword_init: true)

    def self.call(...) = new(...).call

    def initialize(text,
                   parent_tokens: MedSummarizer::Config.parent_chunk_tokens,
                   child_tokens: MedSummarizer::Config.child_chunk_tokens)
      @text = text.to_s
      @parent_tokens = parent_tokens
      @child_tokens = child_tokens
    end

    def call
      parents = []
      pack(paragraphs, @parent_tokens).each_with_index do |parent_text, p_idx|
        children = pack(sentences(parent_text), @child_tokens).each_with_index.map do |child_text, c_idx|
          Child.new(position: c_idx, content: child_text)
        end
        parents << Parent.new(position: p_idx, content: parent_text, children: children)
      end
      parents
    end

    # Rough token estimate (~0.75 words per token for English clinical text).
    def self.estimate_tokens(text)
      (text.to_s.split(/\s+/).reject(&:empty?).size / 0.75).ceil
    end

    private

    def paragraphs
      units = @text.split(/\n{2,}/).map(&:strip).reject(&:empty?)
      units.empty? ? [@text] : units
    end

    def sentences(str)
      # Split on sentence terminators and newlines; keep list-like clinical lines intact.
      parts = str.split(/(?<=[.!?])\s+|\n/).map(&:strip).reject(&:empty?)
      parts.empty? ? [str] : parts
    end

    # Greedily pack text units into windows no larger than `max_tokens`.
    # A single oversized unit is emitted on its own (further split upstream).
    def pack(units, max_tokens)
      windows = []
      buffer = []
      buffer_tokens = 0

      units.each do |unit|
        unit_tokens = self.class.estimate_tokens(unit)
        if buffer.any? && buffer_tokens + unit_tokens > max_tokens
          windows << buffer.join(" ")
          buffer = []
          buffer_tokens = 0
        end
        buffer << unit
        buffer_tokens += unit_tokens
      end

      windows << buffer.join(" ") if buffer.any?
      windows
    end
  end
end
