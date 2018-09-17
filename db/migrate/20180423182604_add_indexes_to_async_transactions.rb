class AddIndexesToAsyncTransactions < ActiveRecord::Migration
  
  disable_ddl_transaction!

  def change
    add_index :async_transactions, :user_uuid, algorithm: :concurrently
    add_index :async_transactions, :source_id, algorithm: :concurrently
    add_index :async_transactions, :transaction_id, algorithm: :concurrently
    add_index :async_transactions, [:transaction_id, :source], unique: true, algorithm: :concurrently
  end
end
