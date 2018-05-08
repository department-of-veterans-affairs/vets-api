class AddUserUuidToDisabilityClaims < ActiveRecord::Migration
  def change
    add_column :disability_claims, :user_uuid, :string, after: :id, null: false
  end
end
