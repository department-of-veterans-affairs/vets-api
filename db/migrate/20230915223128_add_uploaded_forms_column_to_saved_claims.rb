class AddUploadedFormsColumnToSavedClaims < ActiveRecord::Migration[6.1]
  def change
    add_column :saved_claims, :uploaded_forms, :string, array: true
  end
end
