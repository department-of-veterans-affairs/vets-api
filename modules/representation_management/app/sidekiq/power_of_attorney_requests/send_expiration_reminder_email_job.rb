# frozen_string_literal: true

require 'sidekiq'

module PowerOfAttorneyRequests
  class SendExpirationReminderEmailJob
    include Sidekiq::Job

    def perform
      requests_to_remind = fetch_requests_to_remind
      return unless requests_to_remind.any?

      requests_to_remind.each do |request|
        # fetch the request claimant email address and first name
        VANotify::EmailJob.perform_async(
          request.email_address,
          Settings.vanotify.services.va_gov.template_id.appoint_a_representative_confirmation_email,
          {
            'first_name' => request.first_name
          }
        )
      end
    rescue => e
      log_error("Error sending out expiration reminder emails: #{e.message}")
    end

    private

    def fetch_requests_to_remind
      # I think we'll be queyring the power of attorney requests here but I'll confim that
      # when that work is completed and merged.
      # Find all requests that are greater than 30 days old but less than 31 days old.
    end

    def log_error(message)
      Rails.logger.error("SendExpirationReminderEmailJob error: #{message}")
    end
  end
end
