# frozen_string_literal: true

class AllowNullMetadataForRecordMetadata < ActiveRecord::Migration[7.2]
  def change
    change_column_null :claims_api_record_metadata, :metadata_ciphertext, true
  end
end
