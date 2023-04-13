class ReAddInProgressRemindersSent < ActiveRecord::Migration[6.1]
  def change
    create_table :va_notify_in_progress_reminders_sent do |t|
      t.string :form_id, null: false
      t.references :user_account, type: :uuid, foreign_key: :true, null: false, index: true

      t.index ["user_account_id", "form_id"], name: "index_in_progress_reminders_sent_user_account_form_id", unique: true
      t.timestamps
    end
  end
end
