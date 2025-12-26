class MakeUserAccountOptionalInEventBusGatewayNotifications < ActiveRecord::Migration[7.2]
  def change
    change_column_null :event_bus_gateway_notifications, :user_account_id, true
    change_column_null :event_bus_gateway_push_notifications, :user_account_id, true
  end
end
