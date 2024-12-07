class AddIndexesToArPowerOfAttorneyForms < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :ar_power_of_attorney_forms, :city_bidx, algorithm: :concurrently
    add_index :ar_power_of_attorney_forms, :state_bidx, algorithm: :concurrently
    add_index :ar_power_of_attorney_forms, :zipcode_bidx, algorithm: :concurrently
  end
end
