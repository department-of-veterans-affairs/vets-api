class AddIndexesToSavedClaims < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    unless index_exists?(:saved_claims, [:id], name: "index_partial_saved_claims_on_id_metadata_like_error")
      add_index :saved_claims, [:id], where: "(metadata LIKE '%error%')", name: "index_partial_saved_claims_on_id_metadata_like_error", algorithm: :concurrently
    end

    unless index_exists?(:saved_claims, :delete_date)
      add_index :saved_claims, :delete_date, algorithm: :concurrently
    end
  end
end
