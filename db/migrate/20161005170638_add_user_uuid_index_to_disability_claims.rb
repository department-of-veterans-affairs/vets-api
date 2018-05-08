class AddUserUuidIndexToDisabilityClaims < ActiveRecord::Migration
  safety_assured
  
  def change
    add_index :disability_claims, :user_uuid
  end
end
