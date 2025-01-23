class AddMetadataToVANotifyNotifications < ActiveRecord::Migration[7.1]
  def change
    add_column :va_notify_notifications, :metadata, :string
  end
end
