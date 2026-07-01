# frozen_string_literal: true

class CreateSummaries < ActiveRecord::Migration[7.1]
  def change
    create_table :summaries do |t|
      t.references :patient, null: true, foreign_key: true
      t.text    :query, null: false
      t.jsonb   :content, null: false, default: {}, comment: "Structured summary (sections, citations, flags)"
      t.string  :model
      t.string  :prompt_version
      t.integer :prompt_tokens, default: 0
      t.integer :completion_tokens, default: 0
      t.integer :latency_ms, default: 0
      t.float   :confidence, comment: "0.0-1.0; low when evidence is weak/absent"
      t.string  :status, null: false, default: "ok", comment: "ok | no_evidence | blocked | error"
      t.timestamps
    end

    add_index :summaries, :status
  end
end
