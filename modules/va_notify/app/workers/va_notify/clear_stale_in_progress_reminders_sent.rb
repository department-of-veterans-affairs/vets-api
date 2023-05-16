# frozen_string_literal: true

require 'sidekiq'

module VANotify
  class ClearStaleInProgressRemindersSent
    include Sidekiq::Worker

    def perform
      return unless Flipper.enabled?(:clear_stale_in_progress_reminders_sent)

      InProgressRemindersSent.destroy_by('created_at < ?', 60.days.ago)
    end
  end
end
