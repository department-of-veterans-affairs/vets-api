class AddLoginGovAtToAccountLoginStats < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_column :account_login_stats, :logingov_at, :datetime
    add_index :account_login_stats, :logingov_at, algorithm: :concurrently
  end
end
