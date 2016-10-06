class AddUserUuidIndexToDisabilityClaims < ActiveRecord::Migration
  def change
    add_index :disability_claims, :user_uuid
  end
end
