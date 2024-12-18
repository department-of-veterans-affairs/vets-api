# frozen_string_literal: true

require 'sidekiq/monitored_worker'

module Form1010cg
  class SubmissionJob
    STATSD_KEY_PREFIX = "#{Form1010cg::Auditor::STATSD_KEY_PREFIX}.async.".freeze

    DD_ZSF_TAGS = [
      'service:caregiver-application',
      'function: 10-10CG async form submission'
    ].freeze

    CALLBACK_METADATA = {
      callback_metadata: {
        notification_type: 'error',
        form_number: '10-10CG',
        statsd_tags: DD_ZSF_TAGS
      }
    }.freeze

    include Sidekiq::Job
    include Sidekiq::MonitoredWorker
    include SentryLogging

    # retry for  2d 1h 47m 12s
    # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
    sidekiq_options retry: 16

    sidekiq_retries_exhausted do |msg, _e|
      StatsD.increment("#{STATSD_KEY_PREFIX}failed_no_retries_left", tags: ["claim_id:#{msg['args'][0]}"])

      claim = SavedClaim::CaregiversAssistanceClaim.find(msg['args'][0])
      send_failure_email(claim)
    end

    def retry_limits_for_notification
      [1, 10]
    end

    def notify(params)
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
      self.class.send_failure_email(claim)
    rescue => e
      log_exception_to_sentry(e)
      StatsD.increment("#{STATSD_KEY_PREFIX}retries")

      raise
    end

    class << self
      def send_failure_email(claim)
        unless can_send_failure_email?(claim)
          StatsD.increment('silent_failure', tags: DD_ZSF_TAGS)
          return
        end

        StatsD.increment('silent_failure_avoided', tags: DD_ZSF_TAGS)

        parsed_form = claim.parsed_form
        first_name = parsed_form.dig('veteran', 'fullName', 'first')
        email = parsed_form.dig('veteran', 'email')
        template_id = Settings.vanotify.services.health_apps_1010.template_id.form1010_cg_failure_email
        api_key = Settings.vanotify.services.health_apps_1010.api_key
        salutation = first_name ? "Dear #{first_name}," : ''

        VANotify::EmailJob.perform_async(
          email,
          template_id,
          { 'salutation' => salutation },
          api_key,
          CALLBACK_METADATA
        )

        StatsD.increment("#{STATSD_KEY_PREFIX}submission_failure_email_sent")
      end

      private

      def can_send_failure_email?(claim)
        Flipper.enabled?(:caregiver_use_va_notify_on_submission_failure) && claim.parsed_form.dig(
          'veteran', 'email'
        )
      end
    end
  end
end
