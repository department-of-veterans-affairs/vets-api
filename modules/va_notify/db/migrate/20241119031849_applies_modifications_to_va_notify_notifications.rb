class AppliesModificationsToVANotifyNotifications < ActiveRecord::Migration[7.1]
  def change
    add_column :va_notify_notifications, :callback_klass, :text, if_not_exists: true
    add_column :va_notify_notifications, :template_id, :uuid, if_not_exists: true
  end
end
