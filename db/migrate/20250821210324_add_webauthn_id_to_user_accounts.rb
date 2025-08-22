class AddWebauthnIdToUserAccounts < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_column :user_accounts, :webauthn_handle, :string, null: true
    add_index :user_accounts, :webauthn_handle, unique: true, where: "webauthn_handle IS NOT NULL", algorithm: :concurrently
  end
end
