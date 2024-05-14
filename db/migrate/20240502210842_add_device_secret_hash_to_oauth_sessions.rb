class AddDeviceSecretHashToOAuthSessions < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_column :oauth_sessions, :hashed_device_secret, :string, null: true
    add_index :oauth_sessions, :hashed_device_secret, algorithm: :concurrently
  end
end
