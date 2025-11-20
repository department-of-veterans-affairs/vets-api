# frozen_string_literal: true

class RemoveRecordTypeFromRecordMetadata < ActiveRecord::Migration[7.2]
  def change
    safety_assured { remove_column :claims_api_record_metadata, :record_type, :string }
  end
end
