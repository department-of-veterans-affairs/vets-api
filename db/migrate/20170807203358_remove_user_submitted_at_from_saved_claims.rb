class RemoveUserSubmittedAtFromSavedClaims < ActiveRecord::Migration
  def change
    remove_column :saved_claims, :user_submitted_at
  end
end
