class AddIndexesToAsyncTransactions < ActiveRecord::Migration
  def change
    add_index :async_transactions, :user_uuid
    add_index :async_transactions, :source_id
    add_index :async_transactions, :transaction_status
  end
end
