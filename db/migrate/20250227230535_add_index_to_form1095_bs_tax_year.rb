class AddIndexToForm1095BsTaxYear < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :form1095_bs, :tax_year, algorithm: :concurrently
  end
end
