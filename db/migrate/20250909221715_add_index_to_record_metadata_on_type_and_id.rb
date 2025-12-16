# frozen_string_literal: true

class AddIndexToRecordMetadataOnTypeAndId < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :claims_api_record_metadata, %i[record_type record_id],
              name: 'index_record_metadata_on_type_and_id',
              algorithm: :concurrently,
              if_not_exists: true
  end
end
