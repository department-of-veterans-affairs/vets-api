class AddProcIdIndexToClaimsApiPowerOfAttorneyRequests < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_index :claims_api_power_of_attorney_requests, :proc_id, algorithm: :concurrently
  end
end
