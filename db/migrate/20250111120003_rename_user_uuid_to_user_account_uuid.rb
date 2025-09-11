class RenameUserUuidToUserAccountUuid < ActiveRecord::Migration[7.1]
  def change
    safety_assured do
      rename_column :saved_claims, :user_uuid, :user_account_uuid
    end
  end
end
