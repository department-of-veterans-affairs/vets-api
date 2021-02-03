class AddAccountTypes < ActiveRecord::Migration[6.0]
  def change
    add_column :test_user_dashboard_tud_accounts, :id_type, :string
    add_column :test_user_dashboard_tud_accounts, :auth_type, :string
    add_column :test_user_dashboard_tud_accounts, :account_type, :string
  end
end
