class AddAccountToTudAccounts < ActiveRecord::Migration[6.0]
  def change
    add_foreign_key :tud_accounts, :accounts, column: :accounts_id, validate: false
  end
end
