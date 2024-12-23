class MakePoaRequestAndFormAdjustments < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    remove_index :ar_power_of_attorney_forms, name: 'idx_on_city_bidx_state_bidx_zipcode_bidx_a85b76f9bc'
    remove_index :ar_power_of_attorney_forms, name: 'index_ar_power_of_attorney_forms_on_zipcode_bidx'
    safety_assured { remove_columns :ar_power_of_attorney_forms, :city_bidx, :state_bidx, :zipcode_bidx }

    add_column :ar_power_of_attorney_forms, :claimant_city_ciphertext, :string, null: false
    add_column :ar_power_of_attorney_forms, :claimant_city_bidx, :string, null: false

    add_column :ar_power_of_attorney_forms, :claimant_state_code_ciphertext, :string, null: false
    add_column :ar_power_of_attorney_forms, :claimant_state_code_bidx, :string, null: false

    add_column :ar_power_of_attorney_forms, :claimant_zip_code_ciphertext, :string, null: false
    add_column :ar_power_of_attorney_forms, :claimant_zip_code_bidx, :string, null: false

    add_index :ar_power_of_attorney_forms,
              [:claimant_city_bidx, :claimant_state_code_bidx, :claimant_zip_code_bidx],
              algorithm: :concurrently

    add_column :ar_power_of_attorney_requests, :claimant_type, :string, null: false
  end
end
