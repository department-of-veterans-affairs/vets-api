class AddServiceIdToVANotifyNotifications < ActiveRecord::Migration[7.2]
  def change
    add_column :va_notify_notifications, :service_id, :uuid
  end
end
