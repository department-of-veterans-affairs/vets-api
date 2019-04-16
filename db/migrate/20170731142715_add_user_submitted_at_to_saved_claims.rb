class AddUserSubmittedAtToSavedClaims < ActiveRecord::Migration[4.2]
  def change
    # Store this as a string so we can preserve the timezone consistently
    add_column :saved_claims, :user_submitted_at, :string
  end
end
