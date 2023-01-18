class CreateTableUserAcceptableVerifiedCredential < ActiveRecord::Migration[6.1]
  def change
    create_table :user_acceptable_verified_credentials do |t|
      t.datetime :acceptable_verified_credential_at, index: { name: 'index_user_avc_on_acceptable_verified_credential_at'}
      t.datetime :idme_verified_credential_at, index: { name: 'index_user_avc_on_idme_verified_credential_at'}
      t.references :user_account, type: :uuid, foreign_key: :true, null: false, index: { unique: true }
      t.timestamps
    end
  end
end
