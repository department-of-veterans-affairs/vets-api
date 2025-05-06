class AddNewIndexToPoaForms < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :ar_power_of_attorney_forms,
              [:claimant_city_bidx, :claimant_state_code_bidx, :claimant_zip_code_bidx],
              algorithm: :concurrently
  end
end
