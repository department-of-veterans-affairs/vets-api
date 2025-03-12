class AddColumnsToPoaForms < ActiveRecord::Migration[7.1]
  def change
    add_column :ar_power_of_attorney_forms, :claimant_city_ciphertext, :string, null: false
    add_column :ar_power_of_attorney_forms, :claimant_city_bidx, :string, null: false

    add_column :ar_power_of_attorney_forms, :claimant_state_code_ciphertext, :string, null: false
    add_column :ar_power_of_attorney_forms, :claimant_state_code_bidx, :string, null: false

    add_column :ar_power_of_attorney_forms, :claimant_zip_code_ciphertext, :string, null: false
    add_column :ar_power_of_attorney_forms, :claimant_zip_code_bidx, :string, null: false
  end
end
