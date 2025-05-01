class AddRedactedAtToArPowerOfAttorneyRequests < ActiveRecord::Migration[7.2]
  def change
    add_column :ar_power_of_attorney_requests, :redacted_at, :datetime
  end
end
