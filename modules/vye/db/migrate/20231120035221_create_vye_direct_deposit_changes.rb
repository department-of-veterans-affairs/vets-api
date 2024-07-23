# frozen_string_literal: true

class CreateVyeDirectDepositChanges < ActiveRecord::Migration[6.1]
  def change
    create_table :vye_direct_deposit_changes do |t|
      t.integer :user_info_id
      t.string :rpo
      t.string :ben_type
      t.text :full_name_ciphertext
      t.text :phone_ciphertext
      t.text :phone2_ciphertext
      t.text :email_ciphertext
      t.text :acct_no_ciphertext
      t.text :acct_type_ciphertext
      t.text :routing_no_ciphertext
      t.text :chk_digit_ciphertext
      t.text :bank_name_ciphertext
      t.text :bank_phone_ciphertext

      t.text :encrypted_kms_key
      t.timestamps

      t.index :user_info_id
    end
  end
end
