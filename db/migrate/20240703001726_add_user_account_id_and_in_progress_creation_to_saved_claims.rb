class AddUserAccountIdAndInProgressCreationToSavedClaims < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_column :saved_claims, :user_account_id, :uuid, null: true
    add_index :saved_claims, :user_account_id, algorithm: :concurrently
    add_foreign_key :saved_claims, :user_accounts, column: :user_account_id, validate: false
    add_column :saved_claims, :in_progress_form_creation, :datetime
  end
end
