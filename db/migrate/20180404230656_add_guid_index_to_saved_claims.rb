class AddGuidIndexToSavedClaims < ActiveRecord::Migration[4.2]
  disable_ddl_transaction!

  def change
    add_index(:saved_claims, :guid, unique: true, algorithm: :concurrently)
  end
end
