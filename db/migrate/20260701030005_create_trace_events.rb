# frozen_string_literal: true

# TraceEvent is our lightweight, self-hosted observability layer (a LangSmith
# analogue). Every step of the RAG chain writes one row so we can reconstruct
# exactly what was retrieved, what prompt was sent, and what the model returned
# -- this is the evidence used to diagnose and fix hallucinations.
class CreateTraceEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :trace_events do |t|
      t.references :summary, null: true, foreign_key: true
      t.string  :trace_id, null: false, comment: "Groups all events of a single chain run"
      t.string  :step, null: false, comment: "query_parser | retriever | compressor | llm | output_parser | guardrails"
      t.integer :sequence, null: false, default: 0
      t.jsonb   :input, null: false, default: {}
      t.jsonb   :output, null: false, default: {}
      t.integer :tokens, default: 0
      t.integer :latency_ms, default: 0
      t.string  :status, default: "ok"
      t.timestamps
    end

    add_index :trace_events, :trace_id
    add_index :trace_events, [:trace_id, :sequence]
  end
end
