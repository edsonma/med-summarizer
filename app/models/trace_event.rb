# frozen_string_literal: true

class TraceEvent < ApplicationRecord
  belongs_to :summary, optional: true

  scope :for_trace, ->(trace_id) { where(trace_id: trace_id).order(:sequence) }
end
