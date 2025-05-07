# frozen_string_literal: true

require 'zero_silent_failures/monitor'

module Dependents
  ##
  # Monitor functions for Rails logging and StatsD
  #
  class Monitor < ::ZeroSilentFailures::Monitor
    # statsd key for api
    CLAIM_STATS_KEY = 'dependent-change'

    # statsd key for initial sidekiq
    BGS_SUBMISSION_STATS_KEY = 'worker.submit_686c_674_bgs'

    # stats key for pdf submission
    PDF_SUBMISSION_STATS_KEY = 'worker.submit_dependents_pdf'

    # statsd key for backup sidekiq
    SUBMISSION_STATS_KEY = 'worker.submit_686c_674_backup_submission'

    # statsd key for email notifications
    EMAIL_STATS_KEY = 'dependents.email_notification'

    def initialize
      super('dependents-application')
    end

    def track_submission_exhaustion(msg, email = nil)
      additional_context = {
        message: msg
      }
      if email
        # if an email address is present it means an email has been sent by vanotify
        # this means the silent failure is avoided.
        log_silent_failure_no_confirmation(additional_context, call_location: caller_locations.first)
      else
        # if no email is present, log silent failure
        log_silent_failure(additional_context, call_location: caller_locations.first)
      end

      StatsD.increment("#{SUBMISSION_STATS_KEY}.exhausted")
      Rails.logger.error(
        'Failed all retries on Lighthouse::BenefitsIntake::SubmitCentralForm686cJob, ' \
        "last error: #{msg['error_message']}"
      )
    end

    def track_unknown_claim_type(claim_id, e)
      metric = "#{EMAIL_STATS_KEY}.unknown_type"
      payload = { statsd: metric, service:, claim_id:, e: }

      StatsD.increment(metric, tags: ["service:#{service}"])
      Rails.logger.error("Unknown Dependents form type for claim #{claim_id}", payload)
    end

    def track_send_email_success(message, metric, claim_id, user_account_id = nil)
      payload = { statsd: metric, service:, claim_id:, user_account_id: }

      StatsD.increment(metric, tags: ["service:#{service}"])
      Rails.logger.info(message, payload)
    end

    def track_send_email_error(message, metric, claim_id, e, user_account_uuid = nil)
      payload = { statsd: metric, service:, claim_id:, e:, user_account_uuid: }

      StatsD.increment(metric, tags: ["service:#{service}"])
      Rails.logger.error(message, payload)
    end

    def track_send_submitted_email_success(claim_id, user_account_uuid = nil)
      track_send_email_success("'Submitted' email success for claim #{claim_id}",
                               "#{EMAIL_STATS_KEY}.submitted.success",
                               claim_id, user_account_uuid)
    end

    def track_send_submitted_email_failure(claim_id, e, user_account_uuid = nil)
      track_send_email_error("'Submitted' email failure for claim #{claim_id}",
                             "#{EMAIL_STATS_KEY}.submitted.failure",
                             claim_id, e, user_account_uuid)
    end

    def track_send_received_email_success(claim_id, user_account_uuid = nil)
      track_send_email_success("'Received' email success for claim #{claim_id}", "#{EMAIL_STATS_KEY}.received.success",
                               claim_id, user_account_uuid)
    end

    def track_send_received_email_failure(claim_id, e, user_account_uuid = nil)
      track_send_email_failure("'Received' email failure for claim #{claim_id}", "#{EMAIL_STATS_KEY}.received.failure",
                               claim_id, e, user_account_uuid)
    end
  end
end
