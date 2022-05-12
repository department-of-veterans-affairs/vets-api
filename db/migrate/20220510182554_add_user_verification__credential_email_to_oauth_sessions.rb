class AddUserVerificationCredentialEmailToOAuthSessions < ActiveRecord::Migration[6.1]

  def change
    safety_assured do
      add_reference :oauth_sessions, :user_verification, foreign_key: :true, null: true, index: true
    end
    add_column :oauth_sessions, :credential_email, :string
  end
end
