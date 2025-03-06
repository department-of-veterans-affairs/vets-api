class CreateArPowerOfAttorneyRequestNotifications < ActiveRecord::Migration[7.2]
  def change
    create_table :ar_power_of_attorney_request_notifications do |t|
      t.references :power_of_attorney_request, type: :uuid, foreign_key: { to_table: :ar_power_of_attorney_requests }, null: false
      t.references :notification, type: :uuid
      t.string 'type', null: false
      t.timestamps
    end
  end
end
