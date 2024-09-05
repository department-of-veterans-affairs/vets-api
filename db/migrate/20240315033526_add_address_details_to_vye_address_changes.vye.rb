# This migration comes from vye (originally 20240305040113)
class AddAddressDetailsToVyeAddressChanges < ActiveRecord::Migration[7.0]
  def change
    add_column :vye_address_changes, :address_line5_ciphertext, :text
    add_column :vye_address_changes, :address_line6_ciphertext, :text
    add_column :vye_address_changes, :origin, :string
  end
end
