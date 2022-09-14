class AddBackingIdmeUuidToUserVerification < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_column :user_verifications, :backing_idme_uuid, :string
    add_index :user_verifications, :backing_idme_uuid, algorithm: :concurrently
   end
end
