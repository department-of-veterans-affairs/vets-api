class AddConcurrentIndexes < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_index :async_transactions, [:id, :type], algorithm: :concurrently
    add_index :form_attachments, [:id, :type], algorithm: :concurrently
    add_index :persistent_attachments, [:id, :type], algorithm: :concurrently
    add_index :saved_claims, [:id, :type], algorithm: :concurrently
  end
end
