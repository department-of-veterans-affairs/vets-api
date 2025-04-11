class AddRedactedAtIndexToArPowerOfAttorneyRequests < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :ar_power_of_attorney_requests, :redacted_at, algorithm: :concurrently
  end
end
