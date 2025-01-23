class AddColumnMetadataToSavedClaims < ActiveRecord::Migration[7.1]
  def change
    add_column :saved_claims, :metadata, :text
    add_column :saved_claims, :metadata_updated_at, :datetime
  end
end
