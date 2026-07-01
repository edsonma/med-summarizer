# frozen_string_literal: true

class CreateDocuments < ActiveRecord::Migration[7.1]
  def change
    create_table :documents do |t|
      t.references :patient, null: false, foreign_key: true
      t.string  :doc_type, null: false, comment: "lab_report | imaging_report | prescription | clinical_note"
      t.string  :filename
      t.text     :raw_text
      t.jsonb    :metadata, null: false, default: {}
      t.string   :status, null: false, default: "pending", comment: "pending | processing | ingested | failed"
      t.datetime :document_date, comment: "Clinical date of the document (used for date-scoped self-querying)"
      t.datetime :ingested_at
      t.text     :error_message
      t.timestamps
    end

    add_index :documents, :doc_type
    add_index :documents, :status
    add_index :documents, :metadata, using: :gin
  end
end
