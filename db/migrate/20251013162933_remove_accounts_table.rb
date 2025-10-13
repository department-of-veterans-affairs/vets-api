class RemoveAccountsTable < ActiveRecord::Migration[7.2]
  def change
    drop_table :account_login_stats, if_exists: true
    drop_table :accounts, if_exists: true
  end
end
