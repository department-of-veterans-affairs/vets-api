class RemoveVeteranIcnTaxYearIndexFromForm1095B < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    remove_index :form1095_bs, [:veteran_icn, :tax_year], algorithm: :concurrently
  end
end
