class ChangeOauthSessionsClientIdNullFalse < ActiveRecord::Migration[6.1]
  def up
    safety_assured do
      SignIn::OauthSession.delete_all
      change_column_null :oauth_sessions, :client_id, false
    end
  end

  def down
    safety_assured do
      change_column_null :oauth_sessions, :client_id, true
    end
  end
end
