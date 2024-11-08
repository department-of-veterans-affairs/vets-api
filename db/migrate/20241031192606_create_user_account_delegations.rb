class CreateUserAccountDelegations < ActiveRecord::Migration[7.1]
  def change
    create_table :user_account_delegations do |t|
      t.string :verified_user_account_icn, null: false, index: true
      t.string :delegated_user_account_icn, null: false, index: true

      t.timestamps
    end

    add_index :user_account_delegations, %i[verified_user_account_icn delegated_user_account_icn], unique: true
  end
end
