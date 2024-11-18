class AppliesModificationsToVANotifyNotifications < ActiveRecord::Migration[7.1]
  def change
    add_column :va_notify_notifications, :callback_klass, :text
    add_column :va_notify_notifications, :template_id, :uuid

    safety_assured do
      remove_column :va_notify_notifications, :metadata
      remove_column :va_notify_notifications, :callback
    end
  end
end
