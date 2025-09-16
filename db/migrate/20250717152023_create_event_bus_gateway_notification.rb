class CreateEventBusGatewayNotification < ActiveRecord::Migration[7.2]
  def change
    create_table :event_bus_gateway_notifications do |t|
      t.references :user_account, null: false, foreign_key: true, type: :uuid
      t.string :va_notify_id, null: false
      t.string :template_id, null: false
      t.timestamps
    end
  end
end
