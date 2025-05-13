class AddNotNullConstraintToForm1095BVeteranIcnCiphertext < ActiveRecord::Migration[7.2]
  def change
    add_check_constraint :form1095_bs, "veteran_icn_ciphertext IS NOT NULL", name: "form1095_bs_veteran_icn_ciphertext_null", validate: false
  end
end
