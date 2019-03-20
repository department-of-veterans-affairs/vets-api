# frozen_string_literal: true

class CreateSupportingDocuments < ActiveRecord::Migration
  def change
    create_table :claims_api_supporting_documents, id: :uuid do |t|
      t.string   :encrypted_file_data, null: false
      t.string :encrypted_file_data_iv, null: false
      t.integer :auto_established_claim_id, null: false

      t.timestamps null: false
    end
  end
end
