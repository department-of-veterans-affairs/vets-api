class AddBlindIndexToUserCredentialEmailsCredentialEmail < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_column :user_credential_emails, :credential_email_bidx, :string
    add_index :user_credential_emails, :credential_email_bidx, algorithm: :concurrently
  end
end
