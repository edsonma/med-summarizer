# frozen_string_literal: true

require "pdf/reader"

module Ingestion
  # Turns an uploaded artifact (PDF or plain text) into normalized UTF-8 text.
  # Medical documents arrive as scanned/exported PDFs (labs, prescriptions) or
  # plain-text notes; both are reduced to clean text before chunking.
  class TextExtractor
    class ExtractionError < StandardError; end

    def self.call(...) = new(...).call

    # source: an IO, a file path (String), or an UploadedFile.
    def initialize(source, filename: nil, content_type: nil)
      @source = source
      @filename = filename || derive_filename(source)
      @content_type = content_type || derive_content_type(source)
    end

    def call
      normalize(extract_raw)
    end

    private

    attr_reader :source, :filename, :content_type

    def extract_raw
      if pdf?
        extract_pdf
      else
        read_plain
      end
    rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError => e
      raise ExtractionError, "Could not read PDF #{filename}: #{e.message}"
    end

    def pdf?
      content_type.to_s.include?("pdf") || filename.to_s.downcase.end_with?(".pdf")
    end

    def extract_pdf
      io = source.respond_to?(:read) ? source : File.open(source, "rb")
      reader = PDF::Reader.new(io)
      reader.pages.map(&:text).join("\n\n")
    ensure
      io.rewind if io.respond_to?(:rewind)
    end

    def read_plain
      if source.respond_to?(:read)
        source.rewind if source.respond_to?(:rewind)
        source.read
      else
        File.read(source)
      end
    end

    def normalize(text)
      text.to_s
          .encode("UTF-8", invalid: :replace, undef: :replace, replace: " ")
          .gsub(/\r\n?/, "\n")
          .gsub(/[ \t]+\n/, "\n")
          .gsub(/\n{3,}/, "\n\n")
          .strip
    end

    def derive_filename(src)
      return src.original_filename if src.respond_to?(:original_filename)
      return File.basename(src) if src.is_a?(String)

      "document.txt"
    end

    def derive_content_type(src)
      src.respond_to?(:content_type) ? src.content_type : nil
    end
  end
end
