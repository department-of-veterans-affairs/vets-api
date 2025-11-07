# frozen_string_literal: true

class AddIndexToRecordMetadataNeedsKmsRotation < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :claims_api_record_metadata, :needs_kms_rotation, algorithm: :concurrently, if_not_exists: true
  end
end
