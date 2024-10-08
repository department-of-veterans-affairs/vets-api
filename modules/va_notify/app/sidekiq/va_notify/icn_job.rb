# frozen_string_literal: true

module VANotify
  class IcnJob
    include Sidekiq::Job
    include SentryLogging
    sidekiq_options retry: 14

    sidekiq_retries_exhausted do |msg, _ex|
      job_id = msg['jid']
      job_class = msg['class']
      error_class = msg['error_class']
      error_message = msg['error_message']

      message = "#{job_class} retries exhausted"
      Rails.logger.error(message, { job_id:, error_class:, error_message: })
      StatsD.increment("sidekiq.jobs.#{job_class.underscore}.retries_exhausted")
    end

    def perform(icn, template_id, personalisation = nil, api_key = Settings.vanotify.services.va_gov.api_key)
      notify_client = VaNotify::Service.new(api_key)

      notify_client.send_email(
        {
          recipient_identifier: { id_value: icn, id_type: 'ICN' },
          template_id:, personalisation:
        }.compact
      )
      StatsD.increment('api.vanotify.icn_job.success')
    rescue Common::Exceptions::BackendServiceException => e
      handle_backend_exception(e, icn, template_id, personalisation)
    end

    def handle_backend_exception(e, icn, template_id, personalisation)
      if e.status_code == 400
        log_exception_to_sentry(
          e,
          {
            args: { recipient_identifier: { id_value: icn, id_type: 'ICN' },
                    template_id:, personalisation: }
          },
          { error: :va_notify_icn_job }
        )
      else
        raise e
      end
    end
  end
end
