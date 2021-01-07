class ValidateAddAccountToTudAccounts < ActiveRecord::Migration[6.0]
  def change
    validate_foreign_key :tud_accounts, :accounts
  end
end
