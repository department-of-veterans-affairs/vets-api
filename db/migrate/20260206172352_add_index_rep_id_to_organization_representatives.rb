class AddIndexRepIdToOrganizationRepresentatives < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :organization_representatives,
              :representative_id,
              algorithm: :concurrently
  end
end
