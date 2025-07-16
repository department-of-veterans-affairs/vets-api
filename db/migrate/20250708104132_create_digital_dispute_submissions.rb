# frozen_string_literal: true

class CreateDigitalDisputeSubmissions < ActiveRecord::Migration[7.2]
  def change
    create_table :digital_dispute_submissions, id: :uuid do |t|
      t.uuid :user_uuid, null: false
      t.references :user_account, foreign_key: true, type: :uuid
      t.jsonb :debt_identifiers, null: false, default: []
      t.jsonb :public_metadata, default: {}
      t.text :form_data_ciphertext
      t.text :metadata_ciphertext
      t.text :encrypted_kms_key
      t.integer :state, default: 0, null: false
      t.string :error_message
      t.string :reference_id
      t.boolean :needs_kms_rotation, default: false, null: false
      t.timestamps
    end
  end
end
