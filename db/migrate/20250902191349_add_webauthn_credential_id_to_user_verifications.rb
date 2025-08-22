class AddWebauthnCredentialIdToUserVerifications < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :user_verifications, :webauthn_credential, null: true, index: {algorithm: :concurrently, where: 'webauthn_credential_id IS NOT NULL'}, type: :uuid
    add_foreign_key :user_verifications, :sign_in_webauthn_credentials, column: :webauthn_credential_id, validate: false
  end
end
