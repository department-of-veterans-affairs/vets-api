class AddBpdUuidToSavedClaims < ActiveRecord::Migration[7.2]
  def change
    add_column :saved_claims, :bpd_uuid, :uuid
  end
end
