class RemoveInheritedProofVerifiedUserAccounts < ActiveRecord::Migration[7.1]
  def up
    remove_index :inherited_proof_verified_user_accounts, :user_account_id if index_exists?(:inherited_proof_verified_user_accounts, :user_account_id)
    drop_table :inherited_proof_verified_user_accounts
  end

  def down
    create_table :inherited_proof_verified_user_accounts do |t|
      t.uuid :user_account_id, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    add_index :inherited_proof_verified_user_accounts, :user_account_id, name: 'index_inherited_proof_verified_user_accounts_on_user_account_id', unique: true
    add_foreign_key :inherited_proof_verified_user_accounts, :user_accounts, column: :user_account_id
  end
end
