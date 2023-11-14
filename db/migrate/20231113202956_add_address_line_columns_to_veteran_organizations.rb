class AddAddressLineColumnsToVeteranOrganizations < ActiveRecord::Migration[6.1]
  def change
    add_column :veteran_organizations, :address_line1, :string
    add_column :veteran_organizations, :address_line2, :string
    add_column :veteran_organizations, :address_line3, :string
  end
end
