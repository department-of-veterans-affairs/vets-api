class DropNotifyInProgressRemindersSent < ActiveRecord::Migration[6.1]
  def up
    drop_table :va_notify_in_progress_reminders_sent
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
