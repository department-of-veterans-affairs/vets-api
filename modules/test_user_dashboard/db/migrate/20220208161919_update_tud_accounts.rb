class UpdateTudAccounts < ActiveRecord::Migration[6.1]
  def change
    add_column :test_user_dashboard_tud_accounts, :mfa_code, :string
    add_column :test_user_dashboard_tud_accounts, :logingov_uuid, :uuid
    safety_assured { remove_column :test_user_dashboard_tud_accounts, :account_type }
    safety_assured { remove_column :test_user_dashboard_tud_accounts, :id_type }
    add_column :test_user_dashboard_tud_accounts, :id_types, :text, array: true, default: []
  end
end
