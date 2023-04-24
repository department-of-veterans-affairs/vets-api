# frozen_string_literal: true

module VANotify
  class InProgressRemindersSent < ApplicationRecord
    self.table_name = 'va_notify_in_progress_reminders_sent'

    belongs_to :user_account
  end
end
