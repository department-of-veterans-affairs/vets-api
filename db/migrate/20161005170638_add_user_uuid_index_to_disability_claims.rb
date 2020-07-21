class AddUserUuidIndexToDisabilityClaims < ActiveRecord::Migration[4.2]
  safety_assured
  def change
    add_index :disability_claims, :user_uuid
  end
end
