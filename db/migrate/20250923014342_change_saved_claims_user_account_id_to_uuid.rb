class ChangeSavedClaimsUserAccountIdToUuid < ActiveRecord::Migration[7.2]
  def change
    change_column :saved_claims, :user_account_id, :uuid
    SavedClaim.update_all(user_account_id: nil)
  end
end
