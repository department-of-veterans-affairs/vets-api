# frozen_string_literal: true

require 'sidekiq/monitored_worker'

module Form1010cg
  class SubmissionJob
    STATSD_KEY_PREFIX = "#{Form1010cg::Auditor::STATSD_KEY_PREFIX}.async.".freeze
    include Sidekiq::Worker
    include Sidekiq::MonitoredWorker
    include SentryLogging

    sidekiq_options(retry: 22)

    sidekiq_retries_exhausted do |msg, _e|
      StatsD.increment("#{STATSD_KEY_PREFIX}failed_no_retries_left", tags: ["claim_id:#{msg['args'][0]}"])
    end

    def retry_limits_for_notification
      [10]
    end

    def notify(params)
      StatsD.increment("#{STATSD_KEY_PREFIX}failed_ten_retries", tags: ["params:#{params}"])
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
    rescue
      StatsD.increment("#{STATSD_KEY_PREFIX}retries")

      increment_applications_retried(claim_id)

      raise
    end

    private

    def increment_applications_retried(claim_id)
      redis_key = "Form1010cg::SubmissionJob:#{claim_id}"
      return if $redis.get(redis_key).present?

      StatsD.increment("#{STATSD_KEY_PREFIX}applications_retried")

      $redis.set(redis_key, 't')
    end
  end
end
