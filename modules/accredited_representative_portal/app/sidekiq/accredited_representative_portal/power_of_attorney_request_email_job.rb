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

    def perform(poa_request_notification_id,
                personalisation = nil,
                api_key = Settings.vanotify.services.va_gov.api_key)
      notify_client = VaNotify::Service.new(api_key, {})
      poa_request_notification = PowerOfAttorneyRequestNotification.find(poa_request_notification_id)
      template_id = poa_request_notification.template_id

      response = notify_client.send_email(
        {
          email_address: poa_request_notification.email_address,
          template_id:,
          personalisation: generate_personalisation(poa_request_notification) || personalisation
        }.compact
      )
      poa_request_notification.update!(notification_id: response.id)
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

    private

    def generate_personalisation(notification)
      personalisation_klass =
        case notification.type
        when 'requested'
          EmailPersonalisations::Requested
        when 'declined'
          EmailPersonalisations::Declined
        when 'expiring'
          EmailPersonalisations::Expiring
        when 'expired'
          EmailPersonalisations::Expired
        end

      personalisation_klass.generate(
        notification
      )
    end
  end
end
