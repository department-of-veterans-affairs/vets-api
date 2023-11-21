class AddIndexOnLocationToVeteranOrganizations < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_index :veteran_organizations, :location, using: :gist, algorithm: :concurrently
  end
end
