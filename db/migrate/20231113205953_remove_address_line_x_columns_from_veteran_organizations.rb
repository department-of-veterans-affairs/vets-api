class RemoveAddressLineXColumnsFromVeteranOrganizations < ActiveRecord::Migration[6.1]
  def change
    safety_assured {
      remove_column :veteran_organizations, :address_line_1, :string
      remove_column :veteran_organizations, :address_line_2, :string
      remove_column :veteran_organizations, :address_line_3, :string
    }
  end
end
