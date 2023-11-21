class AddAddressToVeteranRepresentative < ActiveRecord::Migration[6.1]
  def change
    add_column :veteran_representatives, :address_line_1, :string
    add_column :veteran_representatives, :address_line_2, :string
    add_column :veteran_representatives, :address_line_3, :string
    add_column :veteran_representatives, :address_type, :string
    add_column :veteran_representatives, :city, :string
    add_column :veteran_representatives, :country_code_iso3, :string
    add_column :veteran_representatives, :country_name, :string
    add_column :veteran_representatives, :county_name, :string
    add_column :veteran_representatives, :county_code, :string
    add_column :veteran_representatives, :international_postal_code, :string
    add_column :veteran_representatives, :province, :string
    add_column :veteran_representatives, :state_code, :string
    add_column :veteran_representatives, :zip_code, :string
    add_column :veteran_representatives, :zip_suffix, :string
    add_column :veteran_representatives, :lat, :float
    add_column :veteran_representatives, :long, :float
    add_column :veteran_representatives, :location, :st_point, geographic: true
    add_column :veteran_representatives, :raw_address, :jsonb
    add_column :veteran_representatives, :full_name, :string
  end
end
