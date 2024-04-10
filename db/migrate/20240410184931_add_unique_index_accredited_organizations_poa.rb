class AddUniqueIndexAccreditedOrganizationsPoa < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :accredited_organizations, :poa_code, unique: true, algorithm: :concurrently
  end
end
