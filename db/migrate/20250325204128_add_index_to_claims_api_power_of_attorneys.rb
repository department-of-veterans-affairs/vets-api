class AddIndexToClaimsApiPowerOfAttorneys < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :claims_api_power_of_attorneys, :form_data_hash, algorithm: :concurrently
  end
end
