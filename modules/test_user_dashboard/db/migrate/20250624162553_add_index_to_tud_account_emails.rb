class AddIndexToTudAccountEmails < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    unless index_exists?(:test_user_dashboard_tud_accounts, :email, name: 'index_test_user_dashboard_tud_accounts_on_email')
      add_index :test_user_dashboard_tud_accounts, :email, unique: true, algorithm: :concurrently, name: 'index_test_user_dashboard_tud_accounts_on_email'
    end
  end

  def down
    if index_exists?(:test_user_dashboard_tud_accounts, :email, name: 'index_test_user_dashboard_tud_accounts_on_email')
      remove_index :test_user_dashboard_tud_accounts, name: 'index_test_user_dashboard_tud_accounts_on_email'
    end
  end
end
