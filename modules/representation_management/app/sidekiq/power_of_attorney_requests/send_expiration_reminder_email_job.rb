# frozen_string_literal: true

require 'sidekiq'

module PowerOfAttorneyRequests
  class SendExpirationReminderEmailJob
    include Sidekiq::Job

    def perform
      requests_to_remind = fetch_requests_to_remind
      return unless requests_to_remind.any?

      requests_to_remind.each do |request|
        notification = request.notifications.create!(type: 'expiring')
        AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob.perform_async(notification.id)
      end
    rescue => e
      log_error("Error sending out expiration reminder emails: #{e.message}")
    end

    private

    def fetch_requests_to_remind
      range = 31.days.ago..30.days.ago

      requests_in_range = AccreditedRepresentativePortal::PowerOfAttorneyRequest
                          .unresolved
                          .where(created_at: range)

      requests_in_range.reject do |request|
        request.notifications.exists?(type: 'expiring')
      end
    end

    def log_error(message)
      Rails.logger.error("SendExpirationReminderEmailJob error: #{message}")
    end
  end
end
