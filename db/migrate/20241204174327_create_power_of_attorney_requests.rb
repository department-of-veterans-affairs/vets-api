class CreatePowerOfAttorneyRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :claims_api_power_of_attorney_requests, id: :uuid do |t|
      t.string :proc_id
      t.string :veteran_icn
      t.string :claimant_icn
      t.string :poa_code
      t.jsonb :metadata, default: {}
      t.uuid :power_of_attorney_id

      t.timestamps
    end
  end
end
