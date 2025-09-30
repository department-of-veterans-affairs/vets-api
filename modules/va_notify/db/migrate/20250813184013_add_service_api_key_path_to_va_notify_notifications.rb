class AddServiceApiKeyPathToVANotifyNotifications < ActiveRecord::Migration[7.2]
  def change
    add_column :va_notify_notifications, :service_api_key_path, :text
  end
end
