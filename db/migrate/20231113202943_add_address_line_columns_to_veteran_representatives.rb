class AddAddressLineColumnsToVeteranRepresentatives < ActiveRecord::Migration[6.1]
  def change
    add_column :veteran_representatives, :address_line1, :string
    add_column :veteran_representatives, :address_line2, :string
    add_column :veteran_representatives, :address_line3, :string
  end
end
