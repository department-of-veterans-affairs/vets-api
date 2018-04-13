class AddGuidIndexToSavedClaims < ActiveRecord::Migration
  disable_ddl_transaction!

  def change
    add_index(:saved_claims, :guid, unique: true, algorithm: :concurrently)
  end
end
