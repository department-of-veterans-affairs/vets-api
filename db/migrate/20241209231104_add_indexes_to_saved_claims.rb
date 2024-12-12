class AddIndexesToSavedClaims < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :saved_claims, [:id], where: "(metadata LIKE '%error%')", name: "index_partial_saved_claims_on_id_metadata_like_error", algorithm: :concurrently
    add_index :saved_claims, :delete_date, algorithm: :concurrently
  end
end
