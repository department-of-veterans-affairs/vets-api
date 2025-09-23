class RecreateUserAccountIdColumnWithIndex < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    safety_assured { remove_column :saved_claims, :user_account_id }
    add_reference :saved_claims, :user_account, type: :uuid, null: true, index: {algorithm: :concurrently}
  end
end
