class AddIndexesToAsyncTransactions < ActiveRecord::Migration
  
  disable_ddl_transaction!

  def change
    add_index :async_transactions, :user_uuid, algorithm: :concurrently
    add_index :async_transactions, :source_id, algorithm: :concurrently
    add_index :async_transactions, :transaction_id, algorithm: :concurrently

    add_index :async_transactions, [:transaction_id, :source], unique: true, algorithm: :concurrently

    # # @TODO Multi-column indexes for the future when we know more about our queries 
    # add_index :async_transactions, [:user_uuid, :source], algorithm: :concurrently
    # add_index :async_transactions, 
    #         [:transaction_id, :source_id, :source], 
    #         algorithm: :concurrently, 
    #         name: 'index_async_tx_on_tx_id_and_source_id_and_source'   
  end
end
