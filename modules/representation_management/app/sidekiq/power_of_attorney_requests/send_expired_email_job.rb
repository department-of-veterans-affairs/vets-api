# frozen_string_literal: true

require 'sidekiq'

module PowerOfAttorneyRequests
  class SendExpiredEmailJob
    # This may change to a job that expires requests then sends an email
    include Sidekiq::Job

    def perform
      requests_to_inform_of_expiration = fetch_requests_to_inform_of_expiration
      return unless requests_to_inform_of_expiration.any?

      requests_to_inform_of_expiration.each do |request|
        notification = request.notifications.create!(type: 'expired')
        AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob.perform_async(notification.id)
      end
    rescue => e
      log_error("Error sending out expiration emails: #{e.message}")
    end

    private

    def fetch_requests_to_inform_of_expiration
      range = 61.days.ago..60.days.ago

      AccreditedRepresentativePortal::PowerOfAttorneyRequest
        .unresolved
        .where(created_at: range)
        .left_outer_joins(:notifications)
        .where.not(ar_power_of_attorney_request_notifications: { type: 'expired' })
    end

    def log_error(message)
      Rails.logger.error("SendExpiredEmailJob error: #{message}")
    end
  end
end
