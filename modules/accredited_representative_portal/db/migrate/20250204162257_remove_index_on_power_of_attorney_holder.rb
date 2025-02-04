class RemoveIndexOnPowerOfAttorneyHolder < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  
  def change
    remove_index :ar_power_of_attorney_requests, name: "index_ar_power_of_attorney_requests_on_power_of_attorney_holder", algorithm: :concurrently
  end
end
