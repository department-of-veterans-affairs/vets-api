# This migration comes from vye (originally 20240429000001)
class GuardedRemoveAddressDetailsFromVyeUserInfos < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      remove_column :vye_user_infos, :full_name_ciphertext if column_exists?(:vye_user_infos, :full_name_ciphertext)
      remove_column :vye_user_infos, :address_line2_ciphertext if column_exists?(:vye_user_infos, :address_line2_ciphertext)
      remove_column :vye_user_infos, :address_line3_ciphertext if column_exists?(:vye_user_infos, :address_line3_ciphertext)
      remove_column :vye_user_infos, :address_line4_ciphertext if column_exists?(:vye_user_infos, :address_line4_ciphertext)
      remove_column :vye_user_infos, :address_line5_ciphertext if column_exists?(:vye_user_infos, :address_line5_ciphertext)
      remove_column :vye_user_infos, :address_line6_ciphertext if column_exists?(:vye_user_infos, :address_line6_ciphertext)
      remove_column :vye_user_infos, :zip_ciphertext if column_exists?(:vye_user_infos, :zip_ciphertext)
    end
  end
end
