class AddUserAccountToTud < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      add_reference :test_user_dashboard_tud_accounts, :user_account, type: :uuid, foreign_key: true, null: true, index: true
      add_reference :test_user_dashboard_tud_account_availability_logs, :user_account, type: :uuid, foreign_key: true, null: true, index: true
    end
  end
end
