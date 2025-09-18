# frozen_string_literal: true

class CreateSavedClaimGroup < ActiveRecord::Migration[7.2]
  def change
    create_table :saved_claim_group do |t|
      t.uuid :claim_group_guid, null: false
      t.integer :parent_claim_id, null: false, comment: 'ID of the saved claim in vets-api'
      t.integer :saved_claim_id, null: false, comment: 'ID of the saved claim in vets-api'
      t.enum :status, enum_type: 'saved_claim_group_status', default: 'pending'
      t.jsonb :user_data_ciphertext, comment: 'encrypted data that can be used to identify the associated user'
      t.text :encrypted_kms_key, comment: 'KMS key used to encrypt the reference data'
      t.boolean :needs_kms_rotation, default: false, null: false

      t.timestamps
    end
  end
end
