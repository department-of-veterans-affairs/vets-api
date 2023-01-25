class CreateUserCredentialEmail < ActiveRecord::Migration[6.1]
  def change
    create_table :user_credential_emails do |t|
      t.references :user_verification, foreign_key: true, index: { unique: true }
      t.text :credential_email_ciphertext
      t.text :encrypted_kms_key
      t.timestamps
    end
  end
end
