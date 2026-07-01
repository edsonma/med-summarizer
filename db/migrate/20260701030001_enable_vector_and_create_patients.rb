# frozen_string_literal: true

class EnableVectorAndCreatePatients < ActiveRecord::Migration[7.1]
  def change
    enable_extension "vector" unless extension_enabled?("vector")

    create_table :patients do |t|
      t.string :mrn, null: false, comment: "Medical Record Number (synthetic in this demo)"
      t.string :name, null: false
      t.timestamps
    end

    add_index :patients, :mrn, unique: true
  end
end
