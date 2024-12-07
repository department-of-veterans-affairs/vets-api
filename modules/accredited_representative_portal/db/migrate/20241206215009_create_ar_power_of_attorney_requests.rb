class CreateArPowerOfAttorneyRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :ar_power_of_attorney_requests, id: :uuid do |t|
      t.references :claimant, type: :uuid
      t.references :latest_status_update, type: :uuid, foreign_key: { to_table: :ar_power_of_attorney_request_status_updates }
      t.datetime :created_at
    end
  end
end
