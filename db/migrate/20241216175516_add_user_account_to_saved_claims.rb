class AddUserAccountToSavedClaims < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :saved_claims, :user_account, null: true, index: {algorithm: :concurrently}
  end
end