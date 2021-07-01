class AddNotesToTudAccounts < ActiveRecord::Migration[6.1]
  def change
    add_column :test_user_dashboard_tud_accounts, :notes, :text
  end
end
