class AddLogingovUuidToAccounts < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_column :accounts, :logingov_uuid, :string
    add_index :accounts, :logingov_uuid, unique: true, algorithm: :concurrently
  end
end
