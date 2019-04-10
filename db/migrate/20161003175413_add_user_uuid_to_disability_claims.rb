class AddUserUuidToDisabilityClaims < ActiveRecord::Migration[4.2]
  def change
    add_column :disability_claims, :user_uuid, :string, after: :id, null: false
  end
end
