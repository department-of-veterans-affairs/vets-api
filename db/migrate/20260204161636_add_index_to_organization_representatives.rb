class AddIndexToOrganizationRepresentatives < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :organization_representatives,
              %i[organization_poa representative_id],
              unique: true,
              name: 'idx_org_reps_on_org_poa_and_rep_id',
              algorithm: :concurrently
  end
end
