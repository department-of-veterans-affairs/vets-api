class AddEncryptedUserAttributesToOAuthSessions < ActiveRecord::Migration[6.1]
  def change
    add_column :oauth_sessions, :user_attributes_ciphertext, :text
    add_column :oauth_sessions, :encrypted_kms_key, :text
  end
end
