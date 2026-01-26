# frozen_string_literal: true

class AddEncryptedKmsKeyAndRotationFlagToRecordMetadata < ActiveRecord::Migration[7.2]
  def change
    add_column :claims_api_record_metadata, :encrypted_kms_key, :text
    add_column :claims_api_record_metadata, :needs_kms_rotation, :boolean, default: false, null: false
  end
end
