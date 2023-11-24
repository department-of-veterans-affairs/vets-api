class AddRepresentativeNumberToVeteranOrganizations < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_column :veteran_organizations, :representative_number, :string
    add_index :veteran_organizations, [:poa, :representative_number], unique: true, algorithm: :concurrently
  end
end
