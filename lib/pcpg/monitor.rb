# frozen_string_literal: true

require 'zero_silent_failures/monitor'

module PCPG
  ##
  # Monitor functions for Rails logging and StatsD
  #
  class Monitor < ::ZeroSilentFailures::Monitor
    # statsd key for api
    CLAIM_STATS_KEY = 'career-guidance-application'

    # statsd key for submit career counseling sidekiq
    SUBMISSION_STATS_KEY = 'worker.lighthouse.submit_career_counseling_job'
    # statsd key for benefits intake sidekiq
    BENEFITS_INTAKE_SUBMISSION_STATS_KEY = 'worker.lighthouse.submit_benefits_intake_claim'

    def initialize
      super('career-guidance-application')
    end

    def track_submission_exhaustion(msg, claim = nil, email = nil)
      user_account_uuid = msg['args'].length <= 1 ? nil : msg['args'][1]
      additional_context = {
        form_id: claim&.form_id,
        claim_id: msg['args'].first,
        confirmation_number: claim&.confirmation_number,
        message: msg
      }

      if email
        # if an email address is present it means an email has been sent by vanotify
        # this means the silent failure is avoided.
        log_silent_failure_no_confirmation(additional_context, user_account_uuid, call_location: caller_locations.first)
      else
        # log_silent_failure calls the ZSF method which increases a special StatsD metric
        # and writes to the Rails log for additional ZSF tracking.
        # if no email is present, log silent failure
        log_silent_failure(additional_context, user_account_uuid, call_location: caller_locations.first)
      end

      StatsD.increment("#{SUBMISSION_STATS_KEY}.exhausted")
      Rails.logger.error(
        "Failed all retries on SubmitCareerCounselingJob, last error: #{msg['error_message']}",
        user_uuid: user_account_uuid, **additional_context
      )
    end

    def track_benefits_intake_submission_exhaustion(msg, claim = nil, email = nil)
      user_account_uuid = msg['args'].length <= 1 ? nil : msg['args'][1]
      additional_context = {
        form_id: claim&.form_id,
        claim_id: msg['args'].first,
        confirmation_number: claim&.confirmation_number,
        message: msg
      }

      if email
        log_silent_failure_no_confirmation(additional_context, user_account_uuid, call_location: caller_locations.first)
      else
        # log_silent_failure calls the ZSF method which increases a special StatsD metric
        # and writes to the Rails log for additional ZSF tracking.
        log_silent_failure(additional_context, user_account_uuid, call_location: caller_locations.first)
      end

      StatsD.increment("#{BENEFITS_INTAKE_SUBMISSION_STATS_KEY}.exhausted")
      Rails.logger.error(
        'Lighthouse::SubmitBenefitsIntakeClaim PCPG 28-8832 submission to LH exhausted!',
        user_uuid: user_account_uuid, **additional_context
      )
    end
  end
end
