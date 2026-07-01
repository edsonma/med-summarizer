# frozen_string_literal: true

class Document < ApplicationRecord
  DOC_TYPES = %w[lab_report imaging_report prescription clinical_note].freeze
  STATUSES  = %w[pending processing ingested failed].freeze

  belongs_to :patient
  has_many :chunks, class_name: "DocumentChunk", dependent: :destroy

  validates :doc_type, presence: true, inclusion: { in: DOC_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :raw_text, presence: true

  scope :ingested, -> { where(status: "ingested") }

  def parent_chunks
    chunks.where(kind: "parent").order(:position)
  end

  def child_chunks
    chunks.where(kind: "child").order(:position)
  end

  def mark_processing!
    update!(status: "processing")
  end

  def mark_ingested!
    update!(status: "ingested", ingested_at: Time.current, error_message: nil)
  end

  def mark_failed!(message)
    update!(status: "failed", error_message: message.to_s.truncate(1000))
  end
end
