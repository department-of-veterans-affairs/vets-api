class CreateEventBusGatewayNotifications < ActiveRecord::Migration[7.2]
  def change
    create_table :event_bus_gateway_notifications, if_not_exists: true do |t|
      t.string :job_id
      t.string :job_class
      t.references :user_account, null: false, foreign_key: true, type: :uuid
      t.string :va_notify_id, null: false
      t.string :va_notify_status
      t.datetime :va_notify_date
      t.string :error_message
      t.timestamps
    end
  end
end
