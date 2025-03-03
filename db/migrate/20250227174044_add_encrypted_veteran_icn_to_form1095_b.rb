class AddEncryptedVeteranIcnToForm1095B < ActiveRecord::Migration[7.2]
  def change
    add_column :form1095_bs, :veteran_icn_ciphertext, :string

    Form1095B.find_each do |form|
      form.update_attribute(:veteran_icn_ciphertext, form.veteran_icn)
    end

    add_check_constraint :form1095_bs, "veteran_icn_ciphertext IS NOT NULL", name: "form1095_bs_veteran_icn_ciphertext_null", validate: false
  end
end
