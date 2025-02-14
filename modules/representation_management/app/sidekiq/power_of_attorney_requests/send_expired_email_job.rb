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
        form = request.power_of_attorney_form
        claimant = form.parsed_data['dependent'] || form.parsed_data['veteran']
        next unless claimant && claimant['email']

        # expire request some how?

        first_name = claimant['name']['first']
        VANotify::EmailJob.perform_async(
          claimant['email'],
          Settings.vanotify.services.va_gov.template_id.appoint_a_rep_expiration_email,
          {
            'first_name' => first_name
          }
        )
      end
    rescue => e
      log_error("Error sending out expiration emails: #{e.message}")
    end

    private

    def fetch_requests_to_inform_of_expiration
      # I think we'll be queyring the power of attorney requests here but I'll confim that
      # when that work is completed and merged.
      # Find all unexpired requests that are greater than 60 days old.
      range = 60.days.ago..Time.zone.now
      AccreditedRepresentativePortal::PowerOfAttorneyRequest.unresolved.not_expired.where(created_at: range)
    end

    def log_error(message)
      Rails.logger.error("SendExpiredEmailJob error: #{message}")
    end
  end
end
