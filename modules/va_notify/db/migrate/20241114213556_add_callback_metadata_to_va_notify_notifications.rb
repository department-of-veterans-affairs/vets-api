class AddCallbackMetadataToVANotifyNotifications < ActiveRecord::Migration[7.1]
  def change
    add_column :va_notify_notifications, :callback_metadata, :jsonb
  end
end
