class AddMetadataToAsyncTransations < ActiveRecord::Migration[4.2]
  def change
    add_column :async_transactions, :encrypted_metadata, :string, unique: false, null: true
    add_column :async_transactions, :encrypted_metadata_iv, :string, unique: false, null: true
  end
end
