class CreateMhvAccounts < ActiveRecord::Migration
  def change
    create_table :mhv_accounts do |t|
      t.string :user_uuid, unique: true, null: false
      t.string :account_state, null: false
      t.datetime :registered_at, null: true
      t.datetime :upgraded_at, null: true

      t.timestamps null: false
    end

    add_index :mhv_accounts, [:user_uuid]
  end
end
