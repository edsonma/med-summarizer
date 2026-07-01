# frozen_string_literal: true

class CreateDocumentChunks < ActiveRecord::Migration[7.1]
  def change
    create_table :document_chunks do |t|
      t.references :document, null: false, foreign_key: true
      # Self-referential parent link enables Parent Document Retrieval:
      # we embed & search small "child" chunks, then return the larger "parent".
      t.references :parent, null: true, foreign_key: { to_table: :document_chunks }
      t.string  :kind, null: false, comment: "parent | child"
      t.integer :position, null: false, default: 0
      t.text    :content, null: false
      t.column  :embedding, "vector(1536)", comment: "text-embedding-3-small; only populated for child chunks"
      t.jsonb   :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :document_chunks, :kind
    add_index :document_chunks, :metadata, using: :gin

    # HNSW index for fast approximate nearest-neighbour search on child chunks.
    # cosine distance matches how OpenAI embeddings are compared.
    execute <<~SQL
      CREATE INDEX index_document_chunks_on_embedding
      ON document_chunks
      USING hnsw (embedding vector_cosine_ops)
      WHERE kind = 'child';
    SQL
  end
end
