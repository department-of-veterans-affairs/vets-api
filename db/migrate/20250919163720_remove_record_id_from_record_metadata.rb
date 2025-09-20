# frozen_string_literal: true

class RemoveRecordIdFromRecordMetadata < ActiveRecord::Migration[7.2]
  def change
    safety_assured { remove_column :claims_api_record_metadata, :record_id, :uuid }
  end
end
