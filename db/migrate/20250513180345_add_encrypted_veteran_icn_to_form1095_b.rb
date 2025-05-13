class AddEncryptedVeteranIcnToForm1095B < ActiveRecord::Migration[7.2]
  def change
    add_column :form1095_bs, :veteran_icn_ciphertext, :string
  end
end
