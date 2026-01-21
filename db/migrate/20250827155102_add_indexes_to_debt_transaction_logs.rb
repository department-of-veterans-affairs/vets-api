class AddIndexesToDebtTransactionLogs < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :debt_transaction_logs, [:user_uuid, :transaction_type], algorithm: :concurrently
    add_index :debt_transaction_logs, :debt_identifiers, using: :gin, algorithm: :concurrently
    add_index :debt_transaction_logs, :transaction_started_at, algorithm: :concurrently
    add_index :debt_transaction_logs, [:transactionable_type, :transactionable_id], algorithm: :concurrently
  end
end
