# frozen_string_literal: true

module Lighthouse
  class SubmitCareerCounselingJob
    include Sidekiq::Job
    include SentryLogging
    RETRY = 14

    STATSD_KEY_PREFIX = 'worker.lighthouse.submit_career_counseling_job'

    sidekiq_options retry: RETRY

    sidekiq_retries_exhausted do |msg, _ex|
      Rails.logger.error(
        "Failed all retries on SubmitCareerCounselingJob, last error: #{msg['error_message']}"
      )
      StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted")
    end

    def perform(claim_id, user_uuid = nil)
      begin
        @claim = SavedClaim.find(claim_id)
        @claim.send_to_benefits_intake!
        send_confirmation_email(user_uuid)
      rescue => e
        log_message_to_sentry('SubmitCareerCounselingJob failed, retrying...', :warn,
                              generate_sentry_details(e))
        raise
      end
      log_message_to_sentry('Successfully submitted form 25-8832', :info, { uuid: user_uuid })
    end

    def send_confirmation_email(user_uuid)
      email = if user_uuid.present? && (found_email = User.find(user_uuid)&.va_profile_email)
                found_email
              else
                @claim.parsed_form.dig('claimantInformation', 'emailAddress')
              end

      if email.blank?
        log_message_to_sentry('No email to send confirmation regarding submitted form 25-8832', :info,
                              { uuid: user_uuid })
        return
      end

      VANotify::EmailJob.perform_async(
        email,
        Settings.vanotify.services.va_gov.template_id.career_counseling_confirmation_email,
        {
          'first_name' => @claim.parsed_form.dig('claimantInformation', 'fullName', 'first')&.upcase.presence,
          'date' => Time.zone.today.strftime('%B %d, %Y')
        }
      )
    end
  end
end
