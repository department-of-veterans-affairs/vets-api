class AddDefaultAttemptsToEventBusGatewayNotifications < ActiveRecord::Migration[7.2]
  def up
    change_column_default :event_bus_gateway_notifications, :attempts, 1
    EventBusGatewayNotification.where(attempts: nil).update_all(attempts: 1)
  end

  def down
    change_column_default :event_bus_gateway_notifications, :attempts, nil
  end
end
