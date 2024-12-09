class AddIndexesToSavedClaims < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :saved_claims, [:metadata, :type], where: "(metadata LIKE '%error%')", name: "idx_saved_claims_partial_metadata_like_error_and_type", algorithm: :concurrently
    add_index :saved_claims, :delete_date, algorithm: :concurrently
  end
end
