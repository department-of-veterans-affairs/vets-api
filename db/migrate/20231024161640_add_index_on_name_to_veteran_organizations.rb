class AddIndexOnNameToVeteranOrganizations < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_index :veteran_organizations, :name, algorithm: :concurrently
  end
end
