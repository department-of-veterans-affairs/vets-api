# frozen_string_literal: true

module DebtManagementCenter
  class VANotifyEmailJob
    include Sidekiq::Job
    include SentryLogging
    STATS_KEY = 'api.dmc.va_notify_email'
    sidekiq_options retry: 14

    class UnrecognizedIdentifier < StandardError; end

    sidekiq_retries_exhausted do |_msg, ex|
      StatsD.increment("#{STATS_KEY}.retries_exhausted")
      Rails.logger.error <<~LOG
        VANotifyEmailJob retries exhausted:
        Exception: #{ex.class} - #{ex.message}
        Backtrace: #{ex.backtrace.join("\n")}
      LOG
    end

    def perform(identifier, template_id, personalisation = nil, id_type = 'email')
      notify_client = VaNotify::Service.new(Settings.vanotify.services.dmc.api_key)
      notify_client.send_email(email_params(identifier, template_id, personalisation, id_type))
      StatsD.increment("#{STATS_KEY}.success")
    rescue => e
      StatsD.increment("#{STATS_KEY}.failure")
      log_exception_to_sentry(
        e,
        {
          args: { template_id: }
        },
        { error: :dmc_va_notify_email_job }
      )
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
  end
end
