class AddClientIdOAuthSessions < ActiveRecord::Migration[6.1]
  def up
    add_column :oauth_sessions, :client_id, :string, null: true
  end

  def down
    remove_column :oauth_sessions, :client_id
  end
end
