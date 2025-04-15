# frozen_string_literal: true

require 'zero_silent_failures/monitor'

module VRE
  ##
  # Monitor functions for Rails logging and StatsD
  #
  class Monitor < ::ZeroSilentFailures::Monitor
    # statsd key for api
    CLAIM_STATS_KEY = 'vre-application'

    # statsd key for initial sidekiq
    SUBMISSION_STATS_KEY = 'worker.vre.submit_1900_job'

    def initialize
      super('vre-application')
    end

    def track_submission_exhaustion(msg, email = nil)
      additional_context = {
        message: msg
      }

      if email
        # if an email address is present it means an email has been sent by vanotify
        # this means the silent failure is avoided.
        log_silent_failure_no_confirmation(additional_context, nil, call_location: caller_locations.first)
      else
        # log_silent_failure calls the ZSF method which increases a special StatsD metric
        # and writes to the Rails log for additional ZSF tracking.
        # if no email is present, log the silent failure.
        log_silent_failure(additional_context, nil, call_location: caller_locations.first)
      end

      StatsD.increment("#{SUBMISSION_STATS_KEY}.exhausted")
      Rails.logger.error(
        "Failed all retries on VRE::Submit1900Job, last error: #{msg['error_message']}"
      )
    end
  end
end
