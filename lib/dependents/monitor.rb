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

    def initialize
      super('dependents-application')
    end

    def track_submission_exhaustion(msg, email = nil)
      additional_context = {
        message: msg
      }
      if email
        log_silent_failure_avoided(additional_context, nil, call_location: caller_locations.first)
      else
        log_silent_failure(additional_context, nil, call_location: caller_locations.first)
      end

      StatsD.increment("#{SUBMISSION_STATS_KEY}.exhausted")
      Rails.logger.error(
        "Failed all retries on CentralMail::SubmitCentralForm686cJob, last error: #{msg['error_message']}"
      )
    end
  end
end
