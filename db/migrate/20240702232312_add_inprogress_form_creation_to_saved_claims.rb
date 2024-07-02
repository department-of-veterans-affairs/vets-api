class AddInprogressFormCreationToSavedClaims < ActiveRecord::Migration[7.1]
  def change
    add_column :saved_claims, :in_progress_form_creation, :datetime
  end
end
