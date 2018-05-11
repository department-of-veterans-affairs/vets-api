class AddUserUuidIndexToDisabilityClaims < ActiveRecord::Migration
  disable_ddl_transaction!

  def change
    add_index :disability_claims, :user_uuid, algorithm: :concurrently
  end
end
