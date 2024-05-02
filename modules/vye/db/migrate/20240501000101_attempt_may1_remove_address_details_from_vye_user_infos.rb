class AttemptMay1RemoveAddressDetailsFromVyeUserInfos < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      remove_column :vye_user_infos, :full_name_ciphertext, :text if column_exists?(:vye_user_infos, :full_name_ciphertext)
      remove_column :vye_user_infos, :address_line2_ciphertext, :text if column_exists?(:vye_user_infos, :address_line2_ciphertext)
      remove_column :vye_user_infos, :address_line3_ciphertext, :text if column_exists?(:vye_user_infos, :address_line3_ciphertext)
      remove_column :vye_user_infos, :address_line4_ciphertext, :text if column_exists?(:vye_user_infos, :address_line4_ciphertext)
      remove_column :vye_user_infos, :address_line5_ciphertext, :text if column_exists?(:vye_user_infos, :address_line5_ciphertext)
      remove_column :vye_user_infos, :address_line6_ciphertext, :text if column_exists?(:vye_user_infos, :address_line6_ciphertext)
      remove_column :vye_user_infos, :zip_ciphertext, :text if column_exists?(:vye_user_infos, :zip_ciphertext)
    end
  end
end
