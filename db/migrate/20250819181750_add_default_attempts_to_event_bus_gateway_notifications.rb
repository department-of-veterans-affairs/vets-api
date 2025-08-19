class AddDefaultAttemptsToEventBusGatewayNotifications < ActiveRecord::Migration[7.2]
  def change
    change_column_default :event_bus_gateway_notifications, :attempts, 1
  end
end
