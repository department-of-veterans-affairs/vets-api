class AddCARMACaseIdIndexToForm1010cgSubmissions < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def change
    add_index :form1010cg_submissions, :carma_case_id, unique: true, algorithm: :concurrently
  end
end
