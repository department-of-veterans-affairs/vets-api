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

    def perform(email, date, confirmation_id)
      @notify_client ||= VaNotify::Service.new
      @notify_client.send_email(
        email_address: email,
        template_id: Settings.vanotify.template_id.covid_vaccine_registration,
        personalisation: {
          'date' => date,
          'confirmation_id' => confirmation_id
        },
        reference: confirmation_id
      )
      StatsD.increment(STATSD_SUCCESS_NAME)
    rescue => e
      handle_errors(e)
    end

    def handle_errors(ex)
      log_exception_to_sentry(ex)
      StatsD.increment(STATSD_ERROR_NAME)

      raise ex
    end
  end
end
