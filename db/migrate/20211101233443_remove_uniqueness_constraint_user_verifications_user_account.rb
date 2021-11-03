class RemoveUniquenessConstraintUserVerificationsUserAccount < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    remove_index :user_verifications, :user_account_id
    add_index :user_verifications, :user_account_id, algorithm: :concurrently
  end
end
