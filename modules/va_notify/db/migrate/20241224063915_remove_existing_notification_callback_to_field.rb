class RemoveExistingNotificationCallbackToField < ActiveRecord::Migration[7.2]
  def change
    safety_assured { remove_column :va_notify_notifications, :to, :string }
  end
end
