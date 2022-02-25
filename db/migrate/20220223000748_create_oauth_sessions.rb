class CreateOAuthSessions < ActiveRecord::Migration[6.1]
  def change
    create_table :oauth_sessions do |t|
      t.uuid :handle, null: false, index: { unique: true }
      t.references :user_account, type: :uuid, foreign_key: :true, null: false, index: true
      t.string :hashed_refresh_token, null: false, index: { unique: true }
      t.timestamp :refresh_expiration, index: true, null: false
      t.timestamp :refresh_creation, index: true, null: false
      t.timestamps
    end
  end
end
