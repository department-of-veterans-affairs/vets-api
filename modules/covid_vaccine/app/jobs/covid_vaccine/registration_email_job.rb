# frozen_string_literal: true

require 'sentry_logging'
require 'va_notify/service'

module CovidVaccine
  class RegistrationEmailJob
    include Sidekiq::Worker
    include SentryLogging
    sidekiq_options expires_in: 1.day, retry: 2

    STATSD_ERROR_NAME = 'worker.covid_vaccine_registration_email.error'
    STATSD_SUCCESS_NAME = 'worker.covid_vaccine_registration_email.success'

    def perform(email, date, sid)
      @notify_client ||= VaNotify::Service.new(Settings.vanotify.services.va_gov.api_key)
      @template_id ||= Settings.vanotify.services.va_gov.template_id.covid_vaccine_registration

      @notify_client.send_email(
        email_address: email,
        template_id: @template_id,
        personalisation: {
          'date' => date,
          'confirmation_id' => sid
        },
        reference: sid
      )
      StatsD.increment(STATSD_SUCCESS_NAME)
    rescue => e
      handle_errors(e, sid)
    end

    def handle_errors(ex, sid)
      log_exception_to_sentry(ex, { sid: })
      StatsD.increment(STATSD_ERROR_NAME)

      raise ex
    end
  end
end
