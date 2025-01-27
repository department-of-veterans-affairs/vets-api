class RemoveCallbackAndMetadataFromVANotifyNotifications < ActiveRecord::Migration[7.1]
  def change
    safety_assured do
      remove_column :va_notify_notifications, :callback, :text
      remove_column :va_notify_notifications, :metadata, :string
    end
  end
end
