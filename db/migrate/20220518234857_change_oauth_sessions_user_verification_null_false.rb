class ChangeOAuthSessionsUserVerificationNullFalse < ActiveRecord::Migration[6.1]
  def up
    safety_assured do
      SignIn::OAuthSession.delete_all
      change_column_null :oauth_sessions, :user_verification_id, false
    end
  end

  def down
    safety_assured do
      change_column_null :oauth_sessions, :user_verification_id, true
    end
  end
end
