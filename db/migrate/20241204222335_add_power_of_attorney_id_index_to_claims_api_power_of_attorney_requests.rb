class AddPowerOfAttorneyIdIndexToClaimsApiPowerOfAttorneyRequests < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :claims_api_power_of_attorney_requests, :power_of_attorney_id, algorithm: :concurrently
  end
end
