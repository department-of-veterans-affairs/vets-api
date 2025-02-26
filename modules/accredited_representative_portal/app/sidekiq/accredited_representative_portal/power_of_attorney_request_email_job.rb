# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestEmailJob
    include Sidekiq::Job
    include SentryLogging
    sidekiq_options retry: 14 # The retry logic here matches VANotify::EmailJob.

    sidekiq_retries_exhausted do |msg, _ex|
      job_id = msg['jid']
      job_class = msg['class']
      error_class = msg['error_class']
      error_message = msg['error_message']

      message = "#{job_class} retries exhausted"
      Rails.logger.error(message, { job_id:, error_class:, error_message: })
      StatsD.increment("sidekiq.jobs.#{job_class.underscore}.retries_exhausted")
    end

    def perform(email,
                template_id,
                poa_request_id,
                request_notification_type,
                api_key = Settings.vanotify.services.va_gov.api_key)
      notify_client = VaNotify::Service.new(api_key, {})

      response = notify_client.send_email(
        {
          email_address: email,
          template_id:
        }.compact
      )
      AccreditedRepresentativePortal::PowerOfAttorneyRequestNotification.create!(
        notification_type: request_notification_type,
        power_of_attorney_request: PowerOfAttorneyRequest.find(poa_request_id),
        notification_id: response['id']
      )
    rescue VANotify::Error => e
      handle_backend_exception(e, template_id)
    end

    def handle_backend_exception(e, template_id)
      if e.status_code == 400
        log_exception_to_sentry(
          e,
          {
            args: { template_id: }
          },
          { error: :accredited_representative_portal_power_of_attorney_request_email_job }
        )
      else
        raise e
      end
    end
  end
end
