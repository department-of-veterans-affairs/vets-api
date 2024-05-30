# frozen_string_literal: true

module VANotify
  class IcnJob
    include Sidekiq::Job
    include SentryLogging
    sidekiq_options retry: 14

    sidekiq_retries_exhausted do |_msg, _ex|
      ::Rails.logger.error(
        'Failure in VANotify::IcnJob#sidekiq_retries_exhausted'
      )
    end

    def perform(icn, template_id, personalisation = nil, api_key = Settings.vanotify.services.va_gov.api_key)
      notify_client = VaNotify::Service.new(api_key)

      notify_client.send_email(
        {
          recipient_identifier: { id_value: icn, id_type: 'ICN' },
          template_id:, personalisation:
        }.compact
      )
    rescue Common::Exceptions::BackendServiceException => e
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
