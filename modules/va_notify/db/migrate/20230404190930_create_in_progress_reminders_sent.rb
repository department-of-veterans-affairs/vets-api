class CreateInProgressRemindersSent < ActiveRecord::Migration[6.1]
  def change
    create_table :va_notify_in_progress_reminders_sent do |t|
      t.string :form_id, null: false
      t.string :user_uuid, null: false

      t.timestamps
    end
  end
end
