class AddIndexForVeteranIcnCiphertextAndTaxYearToForm1095B < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :form1095_bs, [:veteran_icn_ciphertext, :tax_year], unique: true, algorithm: :concurrently
  end
end
