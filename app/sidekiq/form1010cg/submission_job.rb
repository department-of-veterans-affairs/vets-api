# frozen_string_literal: true

require 'sidekiq/monitored_worker'

module Form1010cg
  class SubmissionJob
    STATSD_KEY_PREFIX = "#{Form1010cg::Auditor::STATSD_KEY_PREFIX}.async.".freeze
    include Sidekiq::Job
    include Sidekiq::MonitoredWorker
    include SentryLogging

    sidekiq_options(retry: 22)

    sidekiq_retries_exhausted do |msg, _e|
      StatsD.increment("#{STATSD_KEY_PREFIX}failed_no_retries_left", tags: ["claim_id:#{msg['args'][0]}"])
    end

    def retry_limits_for_notification
      return [1, 10] if Flipper.enabled?(:caregiver1010)

      [10]
    end

    def notify(params)
      unless Flipper.enabled?(:caregiver1010)
        StatsD.increment("#{STATSD_KEY_PREFIX}failed_ten_retries", tags: ["params:#{params}"])
        return
      end

      # Add 1 to retry_count to match retry_monitoring logic
      retry_count = Integer(params['retry_count']) + 1

      StatsD.increment("#{STATSD_KEY_PREFIX}applications_retried") if retry_count == 1
      StatsD.increment("#{STATSD_KEY_PREFIX}failed_ten_retries", tags: ["params:#{params}"]) if retry_count == 10
    end

    def perform(claim_id)
      claim = SavedClaim::CaregiversAssistanceClaim.find(claim_id)

      Form1010cg::Service.new(claim).process_claim_v2!

      begin
        claim.destroy!
      rescue => e
        log_exception_to_sentry(e)
      end
    rescue CARMA::Client::MuleSoftClient::RecordParseError
      StatsD.increment("#{STATSD_KEY_PREFIX}record_parse_error", tags: ["claim_id:#{claim_id}"])
    rescue => e
      log_exception_to_sentry(e)
      StatsD.increment("#{STATSD_KEY_PREFIX}retries")

      increment_applications_retried(claim_id) unless Flipper.enabled?(:caregiver1010)

      raise
    end

    private

    # TODO: @coope93 to remove increment method and feature (:caregiver1010) after validating functionality
    def increment_applications_retried(claim_id)
      redis_key = "Form1010cg::SubmissionJob:#{claim_id}"
      return if $redis.get(redis_key).present?

      StatsD.increment("#{STATSD_KEY_PREFIX}applications_retried")

      $redis.set(redis_key, 't')
    end
  end
end
