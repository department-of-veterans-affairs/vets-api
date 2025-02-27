class AddEncryptedVeteranIcnToForm1095B < ActiveRecord::Migration[7.2]
  def change
    add_column :form1095_bs, :veteran_icn_ciphertext, :string

    Form1095B.find_each do |form|
      form.update_attribute(:veteran_icn_ciphertext, form.veteran_icn)
    end

    # change_column_null :form1095_bs, :veteran_icn_ciphertext, false
    # add_index :form1095_bs, [:veteran_icn_ciphertext, :tax_year], unique: true
  end
end
