# frozen_string_literal: true

module DebtManagementCenter
  class VANotifyEmailJob
    include Sidekiq::Job
    include SentryLogging
    sidekiq_options retry: 14
    STATS_KEY = 'api.dmc.va_notify_email'
    VA_NOTIFY_CALLBACK_OPTIONS = {
      callback_metadata: {
        notification_type: 'error',
        form_number: DebtsApi::V0::Form5655Submission::FORM_ID,
        statsd_tags: {
          service: DebtsApi::V0::Form5655Submission::ZSF_DD_TAG_SERVICE,
          function: DebtsApi::V0::Form5655Submission::ZSF_DD_TAG_FUNCTION
        }
      }
    }.freeze

    class UnrecognizedIdentifier < StandardError; end

    sidekiq_retries_exhausted do |job, ex|
      options = (job['args'][3] || {}).transform_keys(&:to_s)

      StatsD.increment("#{STATS_KEY}.retries_exhausted")
      if options['failure_mailer'] == true
        StatsD.increment("#{DebtsApi::V0::Form5655Submission::STATS_KEY}.send_failed_form_email.failure")
        StatsD.increment('silent_failure', tags: %w[service:debt-resolution function:sidekiq_retries_exhausted])
      end
      Rails.logger.error <<~LOG
        VANotifyEmailJob retries exhausted:
        Exception: #{ex.class} - #{ex.message}
        Backtrace: #{ex.backtrace.join("\n")}
      LOG
    end

    def perform(identifier, template_id, personalisation = nil, options = {})
      options = (options || {}).transform_keys(&:to_s)
      id_type = options['id_type'] || 'email'
      use_failure_mailer = options['failure_mailer']
      notify_client = va_notify_client(use_failure_mailer)
      notify_client.send_email(email_params(identifier, template_id, personalisation, id_type))

      if use_failure_mailer == true
        StatsD.increment("#{DebtsApi::V0::Form5655Submission::STATS_KEY}.send_failed_form_email.success")
      end

      StatsD.increment("#{STATS_KEY}.success")
    rescue => e
      StatsD.increment("#{STATS_KEY}.failure")
      Rails.logger.error("DebtManagementCenter::VANotifyEmailJob failed to send email: #{e.message}")
      log_exception_to_sentry(
        e,
        {
          args: { template_id: }
        },
        { error: :dmc_va_notify_email_job }
      )

      raise e
    end

    def email_params(identifier, template_id, personalisation, id_type)
      case id_type.downcase
      when 'email'
        {
          email_address: identifier,
          template_id:,
          personalisation:
        }.compact
      when 'icn'
        {
          recipient_identifier: { id_value: identifier, id_type: 'ICN' },
          template_id:,
          personalisation:
        }.compact
      else
        raise UnrecognizedIdentifier, id_type
      end
    end

    def va_notify_client(use_failure_mailer)
      if use_failure_mailer == true
        VaNotify::Service.new(Settings.vanotify.services.dmc.api_key, VA_NOTIFY_CALLBACK_OPTIONS)
      else
        VaNotify::Service.new(Settings.vanotify.services.dmc.api_key)
      end
    end
  end
end
