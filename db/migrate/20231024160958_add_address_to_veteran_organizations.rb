class AddAddressToVeteranOrganizations < ActiveRecord::Migration[6.1]
  def change
    add_column :veteran_organizations, :address_line_1, :string
    add_column :veteran_organizations, :address_line_2, :string
    add_column :veteran_organizations, :address_line_3, :string
    add_column :veteran_organizations, :address_type, :string
    add_column :veteran_organizations, :city, :string
    add_column :veteran_organizations, :country_code_iso3, :string
    add_column :veteran_organizations, :country_name, :string
    add_column :veteran_organizations, :county_name, :string
    add_column :veteran_organizations, :county_code, :string
    add_column :veteran_organizations, :international_postal_code, :string
    add_column :veteran_organizations, :province, :string
    add_column :veteran_organizations, :state_code, :string
    add_column :veteran_organizations, :zip_code, :string
    add_column :veteran_organizations, :zip_suffix, :string
    add_column :veteran_organizations, :lat, :float
    add_column :veteran_organizations, :long, :float
    add_column :veteran_organizations, :location, :st_point, geographic: true
    add_column :veteran_organizations, :raw_address, :jsonb
  end
end
