class AddUserAccountToSavedClaims < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_reference :saved_claims, :user_accounts, null: true, index: {algorithm: :concurrently}
  end
end
