class AddRedactedAtIndexToArPowerOfAttorneyRequests < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    unless index_exists?(:ar_power_of_attorney_requests, :redacted_at, name: 'index_ar_power_of_attorney_requests_on_redacted_at')
      add_index :ar_power_of_attorney_requests, :redacted_at, algorithm: :concurrently, name: 'index_ar_power_of_attorney_requests_on_redacted_at'
    end
  end
end
