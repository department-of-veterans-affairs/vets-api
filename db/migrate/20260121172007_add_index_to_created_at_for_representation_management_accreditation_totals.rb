class AddIndexToCreatedAtForRepresentationManagementAccreditationTotals < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :representation_management_accreditation_totals, :created_at, algorithm: :concurrently
  end
end
