class CreateSignInWebauthnCredentials < ActiveRecord::Migration[7.2]
  def change
    create_table :sign_in_webauthn_credentials, id: :uuid do |t|
      t.string     :credential_id, null: false, index: { unique: true }
      t.text       :public_key, null: false
      t.bigint     :sign_count, null: false, default: 0
      t.string     :transports, array: true, default: []
      t.uuid       :aaguid
      t.boolean    :backup_eligible, null: false, default: false
      t.boolean    :backed_up, null: false, default: false
      t.timestamps
    end
  end
end
