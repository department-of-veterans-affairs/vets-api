class AddColumnMetadataToSavedClaims < ActiveRecord::Migration[7.1]
  def change
    add_column :saved_claims, :metadata, :string
  end
end
