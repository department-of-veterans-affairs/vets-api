# frozen_string_literal: true
# This migration comes from vye (originally 20231120035049)

class CreateVyeAddressChanges < ActiveRecord::Migration[6.1]
  def change
    create_table :vye_address_changes do |t|
      t.integer :user_info_id
      t.string :rpo
      t.string :benefit_type
      t.text :veteran_name_ciphertext
      t.text :address1_ciphertext
      t.text :address2_ciphertext
      t.text :address3_ciphertext
      t.text :address4_ciphertext
      t.text :city_ciphertext
      t.text :state_ciphertext
      t.text :zip_code_ciphertext
      
      t.text :encrypted_kms_key
      t.timestamps

      t.index :user_info_id      
    end
  end
end
