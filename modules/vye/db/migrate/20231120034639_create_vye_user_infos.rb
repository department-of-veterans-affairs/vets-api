# frozen_string_literal: true

class CreateVyeUserInfos < ActiveRecord::Migration[6.1]
  def change
    create_table :vye_user_infos do |t|
      t.string :icn
      t.string :ssn_digest
      t.text :ssn_ciphertext
      t.text :file_number_ciphertext
      t.string :suffix
      t.text :full_name_ciphertext
      t.text :address_line2_ciphertext
      t.text :address_line3_ciphertext
      t.text :address_line4_ciphertext
      t.text :address_line5_ciphertext
      t.text :address_line6_ciphertext
      t.text :zip_ciphertext
      t.text :dob_ciphertext
      t.text :stub_nm_ciphertext
      t.string :mr_status
      t.string :rem_ent
      t.datetime :cert_issue_date
      t.datetime :del_date
      t.datetime :date_last_certified
      t.integer :rpo_code
      t.string :fac_code
      t.decimal :payment_amt
      t.string :indicator

      t.text :encrypted_kms_key
      t.timestamps

      t.index :icn
      t.index :ssn_digest
    end
  end
end
