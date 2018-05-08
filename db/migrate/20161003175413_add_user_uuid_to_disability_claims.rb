class AddUserUuidToDisabilityClaims < ActiveRecord::Migration
  safety_assured
  
  def change
    add_column :disability_claims, :user_uuid, :string, after: :id, null: false
  end
end
