# frozen_string_literal: true

class Summary < ApplicationRecord
  belongs_to :patient, optional: true
  has_many :trace_events, dependent: :destroy

  STATUSES = %w[ok no_evidence blocked error].freeze
  validates :status, inclusion: { in: STATUSES }
  validates :query, presence: true

  # content is a structured hash:
  # {
  #   "headline" => "...",
  #   "sections" => [{ "title" => "...", "body" => "...", "citations" => ["chunk-12"] }],
  #   "flags"    => ["..."],
  #   "disclaimer" => "...",
  #   "citations" => [{ "ref" => "chunk-12", "doc_type" => "lab_report", "excerpt" => "..." }]
  # }
  def sections
    Array(content["sections"])
  end

  def citations
    Array(content["citations"])
  end

  def flags
    Array(content["flags"])
  end

  def headline
    content["headline"]
  end

  def disclaimer
    content["disclaimer"]
  end

  def grounded?
    status == "ok" && citations.any?
  end
end
