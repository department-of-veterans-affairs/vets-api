class AddAllCredentialEmailsToOAuthSessions < ActiveRecord::Migration[7.1]
  def change
    add_column :oauth_sessions, :all_credential_emails, :string, array: true, default: []
  end
end
