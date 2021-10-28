class CreateUserAccounts < ActiveRecord::Migration[6.1]
  def change
    create_table :user_accounts, id: :uuid do |t|
      t.string :icn
      t.timestamps
      t.index :icn, name: "index_user_accounts_on_icn", unique: true
    end
  end
end
