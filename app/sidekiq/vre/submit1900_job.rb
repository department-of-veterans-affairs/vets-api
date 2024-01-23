# frozen_string_literal: true

module VRE
  class Submit1900Job
    include Sidekiq::Job
    include SentryLogging

    STATSD_KEY_PREFIX = 'worker.vre.submit_1900_job'
    RETRY = 14

    sidekiq_options retry: RETRY

    sidekiq_retries_exhausted do |msg, _ex|
      Rails.logger.error(
        "Failed all retries on VRE::Submit1900Job, last error: #{msg['error_message']}"
      )
      StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted")
    end

    def perform(claim_id, user_uuid)
      claim = SavedClaim::VeteranReadinessEmploymentClaim.find claim_id
      user = User.find user_uuid
      claim.add_claimant_info(user)
      claim.send_to_vre(user)
    rescue => e
      log_message_to_sentry(
        'VRE::Submit1900Job failed, retrying...', :warn, generate_sentry_details(e)
      )
      raise
    end
  end
end
