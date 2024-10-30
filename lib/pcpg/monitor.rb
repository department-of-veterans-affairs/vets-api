# frozen_string_literal: true

require 'zero_silent_failures/monitor'

module PCPG
  ##
  # Monitor functions for Rails logging and StatsD
  #
  class Monitor < ::ZeroSilentFailures::Monitor
    # statsd key for api
    CLAIM_STATS_KEY = 'career-guidance-application'

    # statsd key for initial sidekiq
    SUBMISSION_STATS_KEY = 'worker.lighthouse.submit_benefits_intake_claim'

    def initialize
      super('career-guidance-application')
    end

    def track_submission_exhaustion(msg, claim = nil)
      user_account_uuid = msg['args'].length <= 1 ? nil : msg['args'][1]
      additional_context = {
        form_id: claim&.form_id,
        claim_id: msg['args'].first,
        confirmation_number: claim&.confirmation_number,
        message: msg
      }
      # log_silent_failure calls the ZSF method which increases a special StatsD metric
      # and writes to the Rails log for additional ZSF tracking.
      log_silent_failure(additional_context, user_account_uuid, call_location: caller_locations.first)

      StatsD.increment("#{SUBMISSION_STATS_KEY}.exhausted")
      Rails.logger.error(
        "Lighthouse::SubmitBenefitsIntakeClaim PCPG 28-8832 submission to LH exhausted!", 
        user_uuid: user_account_uuid, **additional_context)
    end
  end
end