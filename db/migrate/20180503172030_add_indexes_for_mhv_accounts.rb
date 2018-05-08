class AddIndexesForMhvAccounts < ActiveRecord::Migration
  disable_ddl_transaction!

  def change
    add_index :mhv_accounts, [:user_uuid], unique: false, algorithm: :concurrently
    add_index :mhv_accounts, [:user_uuid, :mhv_correlation_id], unique: true, algorithm: :concurrently
  end
end
