# frozen_string_literal: true

# SubmissionJob
#
# This Sidekiq job processes and submits 10-10CG (Caregiver Assistance) claims to the CARMA backend.
# It manages the full lifecycle of a claim submission, including error handling, logging, and notification.
#
# Why:
# - Automates the asynchronous submission of caregiver claims, improving reliability and scalability.
# - Ensures claims are processed even if the web request fails or times out.
# - Provides robust error handling, retry logic, and user notification on failure.
#
# How:
# - Loads the claim by ID and processes it using Form1010cg::Service.
# - Destroys the claim after successful processing to prevent duplicate submissions.
# - Handles and logs errors, including parsing errors from CARMA and general exceptions.
# - Sends failure notification emails to users if submission fails after all retries.
# - Tracks job metrics and durations for monitoring and analytics.

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

    # retry for  2d 1h 47m 12s
    # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
    sidekiq_options retry: 16

    sidekiq_retries_exhausted do |msg, _e|
      claim_id = msg['args'][0]
      StatsD.increment("#{STATSD_KEY_PREFIX}failed_no_retries_left", tags: ["claim_id:#{claim_id}"])

      claim = SavedClaim::CaregiversAssistanceClaim.find(claim_id)
      send_failure_email(claim)
    end

    def retry_limits_for_notification
      [1, 10]
    end

    def notify(params)
      # Add 1 to retry_count to match retry_monitoring logic
      retry_count = Integer(params['retry_count']) + 1
      claim_id = params['args'][0]

      StatsD.increment("#{STATSD_KEY_PREFIX}applications_retried") if retry_count == 1
      if retry_count == 10
        StatsD.increment("#{STATSD_KEY_PREFIX}failed_ten_retries",
                         tags: ["params:#{params}", "claim_id:#{claim_id}"])
      end
    end

    def perform(claim_id)
      start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
      claim = SavedClaim::CaregiversAssistanceClaim.find(claim_id)

      Form1010cg::Service.new(claim).process_claim_v2!

      begin
        claim.destroy!
      rescue => e
        log_error(e, '[10-10CG] - Error destroying Caregiver claim after processing submission in job', claim_id)
      end
      Form1010cg::Auditor.new.log_caregiver_request_duration(context: :process_job, event: :success, start_time:)
    rescue CARMA::Client::MuleSoftClient::RecordParseError
      StatsD.increment("#{STATSD_KEY_PREFIX}record_parse_error", tags: ["claim_id:#{claim_id}"])
      Form1010cg::Auditor.new.log_caregiver_request_duration(context: :process_job, event: :failure, start_time:)
      self.class.send_failure_email(claim)
    rescue => e
      log_error(e, '[10-10CG] - Error processing Caregiver claim submission in job', claim_id)
      StatsD.increment("#{STATSD_KEY_PREFIX}retries")
      Form1010cg::Auditor.new.log_caregiver_request_duration(context: :process_job, event: :failure, start_time:)

      raise
    end

    class << self
      def send_failure_email(claim)
        unless claim.parsed_form.dig('veteran', 'email')
          StatsD.increment('silent_failure', tags: DD_ZSF_TAGS)
          return
        end

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

        StatsD.increment("#{STATSD_KEY_PREFIX}submission_failure_email_sent", tags: ["claim_id:#{claim.id}"])
      end
    end

    private

    def log_error(exception, message, claim_id)
      Rails.logger.error(message, { exception:, claim_id: })
    end
  end
end
