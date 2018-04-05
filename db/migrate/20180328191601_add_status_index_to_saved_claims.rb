class AddStatusIndexToSavedClaims < ActiveRecord::Migration
  disable_ddl_transaction!

  def change
    add_index(:saved_claims, [:created_at, :status, :form_id], algorithm: :concurrently)
  end
end
