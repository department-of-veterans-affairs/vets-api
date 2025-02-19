class AddVANotifyNotificationsIndex < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :va_notify_notifications, :notification_id, algorithm: :concurrently
  end
end
