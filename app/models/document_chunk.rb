# frozen_string_literal: true

class DocumentChunk < ApplicationRecord
  # neighbor gem: enables `DocumentChunk.nearest_neighbors(:embedding, vec, distance: "cosine")`
  has_neighbors :embedding

  belongs_to :document
  belongs_to :parent, class_name: "DocumentChunk", optional: true
  has_many :children, class_name: "DocumentChunk", foreign_key: :parent_id, dependent: :destroy

  validates :kind, inclusion: { in: %w[parent child] }
  validates :content, presence: true

  scope :children_only, -> { where(kind: "child") }
  scope :parents_only, -> { where(kind: "parent") }

  # A stable, human-readable citation handle surfaced to the LLM and the UI.
  def citation_ref
    "chunk-#{id}"
  end

  def doc_type
    metadata["doc_type"] || document&.doc_type
  end
end
