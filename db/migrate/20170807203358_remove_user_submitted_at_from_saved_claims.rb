class RemoveUserSubmittedAtFromSavedClaims < ActiveRecord::Migration[4.2]
  def change
    remove_column :saved_claims, :user_submitted_at
  end
end
