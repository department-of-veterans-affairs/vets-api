class AddCredentialAttributesDigestColumnToUserVerifications < ActiveRecord::Migration[7.2]
  def change
    add_column :user_verifications, :credential_attributes_digest, :string, null: true
  end
end
