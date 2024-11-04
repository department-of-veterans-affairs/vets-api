# frozen_string_literal: true

module VANotify
  class InProgressFormReminderCallback
    def self.call(notification)
      Rails.logger.info(message: "VANotify - in_progress_form_reminder for notification: #{notification.id}",
                        status: notification.status, status_reason: notification.status_reason,
                        metadata: notification.metadata)
    end
  end
end
