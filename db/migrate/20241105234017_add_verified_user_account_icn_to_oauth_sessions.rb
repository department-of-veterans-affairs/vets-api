class AddVerifiedUserAccountIcnToOAuthSessions < ActiveRecord::Migration[7.1]
  def change
    add_column :oauth_sessions, :verified_user_account_icn, :string, default: nil

    add_index :oauth_sessions, :verified_user_account_icn, algorithm: :concurrently
  end
end
