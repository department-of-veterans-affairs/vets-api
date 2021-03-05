class RemoveStandardAvailableFromTudAccounts < ActiveRecord::Migration[6.0]
  def change
    safety_assured {
      remove_column :test_user_dashboard_tud_accounts, :standard
      remove_column :test_user_dashboard_tud_accounts, :available
    }
  end
end
