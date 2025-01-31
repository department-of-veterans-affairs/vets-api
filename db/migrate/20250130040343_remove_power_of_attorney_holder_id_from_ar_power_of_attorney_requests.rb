class RemovePowerOfAttorneyHolderIdFromArPowerOfAttorneyRequests < ActiveRecord::Migration[7.2]
  def up
    safety_assured do
      remove_index :ar_power_of_attorney_requests, name: "index_ar_power_of_attorney_requests_on_power_of_attorney_holder"
      remove_column :ar_power_of_attorney_requests, :power_of_attorney_holder_id
    end
  end

  def down
    add_column :ar_power_of_attorney_requests, :power_of_attorney_holder_id, :uuid
    add_index :ar_power_of_attorney_requests, [:power_of_attorney_holder_type, :power_of_attorney_holder_id], name: "index_ar_power_of_attorney_requests_on_power_of_attorney_holder"
  end
end
