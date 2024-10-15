class CreateVANotifyNotifications < ActiveRecord::Migration[7.1]
  def change
    create_table :va_notify_notifications do |t|
      t.uuid :notification_id, null: false
      t.text :reference
      t.text :to
      t.text :status
      t.datetime :completed_at
      t.datetime :sent_at
      t.text :notification_type
      t.text :status_reason
      t.text :provider
      t.text :source_location
      t.text :callback

      t.timestamps
    end
  end
end
