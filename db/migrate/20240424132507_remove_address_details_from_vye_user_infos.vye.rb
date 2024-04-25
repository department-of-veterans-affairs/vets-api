# This migration comes from vye (originally 20240305034315)
class RemoveAddressDetailsFromVyeUserInfos < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      remove_columns(
        :vye_user_infos,
        :full_name_ciphertext,
        :address_line2_ciphertext,
        :address_line3_ciphertext,
        :address_line4_ciphertext,
        :address_line5_ciphertext,
        :address_line6_ciphertext,
        :zip_ciphertext
      )
    end
  end
end
