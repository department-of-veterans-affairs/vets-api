# frozen_string_literal: true

class CreateRecordMetadata < ActiveRecord::Migration[7.2]
  def change
    create_table :claims_api_record_metadata, id: :uuid do |t|
      t.text :metadata_ciphertext, null: false
      t.string :record_type, null: false
      t.uuid :record_id, null: false

      t.timestamps
    end
  end
end
