class RemovePowerOfAttorneyHolderIdFromArPowerOfAttorneyRequests < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      remove_column :ar_power_of_attorney_requests, :power_of_attorney_holder_id
    end
  end
end
