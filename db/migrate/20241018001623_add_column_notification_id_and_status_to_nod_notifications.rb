class AddColumnNotificationIdAndStatusToNodNotifications < ActiveRecord::Migration[7.1]
  def change
    add_column :nod_notifications, :notification_id, :string
    add_column :nod_notifications, :status, :string
  end
end
