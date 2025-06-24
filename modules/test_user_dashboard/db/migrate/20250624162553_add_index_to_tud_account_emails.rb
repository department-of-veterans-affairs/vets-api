class AddIndexToTudAccountEmails < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :test_user_dashboard_tud_accounts, :email, unique: true, algorithm: :concurrently, name: 'index_test_user_dashboard_tud_accounts_on_email'
  end
end
