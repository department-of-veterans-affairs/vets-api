class AddIdmeUuidToTudAccounts < ActiveRecord::Migration[6.0]
  def change
    add_column :test_user_dashboard_tud_accounts, :idme_uuid, :uuid
  end
end
