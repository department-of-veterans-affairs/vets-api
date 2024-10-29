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

    def track_submission_exhaustion(msg)
      additional_context = {
        message: msg
      }
      # log_silent_failure calls the ZSF method which increases a special StatsD metric
      # and writes to the Rails log for additional ZSF tracking.
      log_silent_failure(additional_context, nil, call_location: caller_locations.first)

      StatsD.increment("#{SUBMISSION_STATS_KEY}.exhausted")
      Rails.logger.error(
        "Failed all retries on VRE::Submit1900Job, last error: #{msg['error_message']}"
      )
    end
  end
end
