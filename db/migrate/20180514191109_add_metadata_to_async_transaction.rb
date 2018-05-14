class AddMetadataToAsyncTransaction < ActiveRecord::Migration
  def change
    add_column :async_transactions, :metadata, :string, unique: false, null: true
    add_column :async_transactions, :metadata_vi, :string, unique: false, null: true
  end
end
