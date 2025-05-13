class RemoveIndexConstraintAndAddColumnConstraint < ActiveRecord::Migration[7.2]
  def up
    validate_check_constraint :form1095_bs, name: "form1095_bs_veteran_icn_ciphertext_null"
    change_column_null :form1095_bs, :veteran_icn_ciphertext, false
    remove_check_constraint :form1095_bs, name: "form1095_bs_veteran_icn_ciphertext_null"
  end

  def down
    add_check_constraint :form1095_bs, "veteran_icn_ciphertext IS NOT NULL", name: "form1095_bs_veteran_icn_ciphertext_null", validate: false
    change_column_null :form1095_bs, :veteran_icn_ciphertext, true
  end
end
