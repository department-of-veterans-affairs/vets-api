# frozen_string_literal: true

require 'sidekiq'

module PowerOfAttorneyRequests
  class SendExpiredEmailJob # This may change to a job that expires requests then sends an email
    include Sidekiq::Job

    def perform
      requests_to_inform_of_expiration = fetch_requests_to_inform_of_expiration
      return unless requests_to_inform_of_expiration.any?

      requests_to_inform_of_expiration.each_with_index do |request, index|
        # fetch the request claimant email address and first name
        #
        # expire the request by modifying the request itself.
        VANotify::EmailJob.perform_in(index.minutes + 1,
                                      request.email_address,
                                      Settings.vanotify.services.va_gov.template_id.appoint_a_representative_confirmation_email,
                                      {
                                        'first_name' => request.first_name
                                      })
      end
    rescue => e
      log_error("Error sending out expiration emails: #{e.message}")
    end

    private

    def fetch_requests_to_inform_of_expiration
      # I think we'll be queyring the power of attorney requests here but I'll confim that
      # when that work is completed and merged.
      # Find all requests that are greater than 60 days old.
    end

    def log_error(message)
      Rails.logger.error("SendExpiredEmailJob error: #{message}")
    end
  end
end
