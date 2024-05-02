class AddAddressDetailsFromVyeUserInfos < ActiveRecord::Migration[7.1]
  def change
    add_column :vye_user_infos, :full_name_ciphertext, :text, if_not_exists: true
    add_column :vye_user_infos, :address_line2_ciphertext, :text, if_not_exists: true
    add_column :vye_user_infos, :address_line3_ciphertext, :text, if_not_exists: true
    add_column :vye_user_infos, :address_line4_ciphertext, :text, if_not_exists: true
    add_column :vye_user_infos, :address_line5_ciphertext, :text, if_not_exists: true
    add_column :vye_user_infos, :address_line6_ciphertext, :text, if_not_exists: true
    add_column :vye_user_infos, :zip_ciphertext, :text, if_not_exists: true
  end
end
