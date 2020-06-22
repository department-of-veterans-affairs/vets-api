class AddIndexesForMhvAccounts < ActiveRecord::Migration[4.2]
  disable_ddl_transaction!

  def change
    add_index :mhv_accounts, [:user_uuid, :mhv_correlation_id], unique: true, algorithm: :concurrently
  end
end
