class AddCurrentVerificationToAccountLoginStats < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_column :account_login_stats, :current_verification, :string
    add_index :account_login_stats, :current_verification, algorithm: :concurrently
  end
end
