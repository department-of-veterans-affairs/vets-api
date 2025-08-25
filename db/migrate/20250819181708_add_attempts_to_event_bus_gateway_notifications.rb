class AddAttemptsToEventBusGatewayNotifications < ActiveRecord::Migration[7.2]
  def change
    add_column :event_bus_gateway_notifications, :attempts, :integer
  end
end
