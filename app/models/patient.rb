# frozen_string_literal: true

class Patient < ApplicationRecord
  has_many :documents, dependent: :destroy
  has_many :summaries, dependent: :nullify

  validates :mrn, presence: true, uniqueness: true
  validates :name, presence: true

  def label
    "#{name} (MRN #{mrn})"
  end
end
