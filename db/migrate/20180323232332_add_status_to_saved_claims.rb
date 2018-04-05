class AddStatusToSavedClaims < ActiveRecord::Migration
  def change
    add_column :saved_claims, :status, :string
  end
end
