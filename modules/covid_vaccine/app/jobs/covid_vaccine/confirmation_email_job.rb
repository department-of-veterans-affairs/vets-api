# frozen_string_literal: true

require 'sentry_logging'
require 'va_notify/service'

module CovidVaccine
  class ConfirmationEmailJob
    include Sidekiq::Worker
    include SentryLogging
    sidekiq_options expires_in: 1.day, retry: 2

    STATSD_ERROR_NAME = 'worker.covid_vaccine_confirmation_email.error'
    STATSD_SUCCESS_NAME = 'worker.covid_vaccine_confirmation_email.success'

    def perform(email, date, sid)
      submission = CovidVaccine::V0::RegistrationSubmission.find_by(sid: sid)
      if submission.nil?
        log_message_to_sentry('No SID found!', :warn, { email: email, sid: sid })
        return
      end
      return if submission.email_confirmation_id.present?

      if Flipper.enabled?(:vanotify_service_enhancement)
        notify_client ||= VaNotify::Service.new(Settings.vanotify.services.va_gov.api_key)
        template_id ||= Settings.vanotify.services.va_gov.template_id.covid_vaccine_registration
      else
        notify_client ||= VaNotify::Service.new(Settings.vanotify.api_key)
        template_id ||= Settings.vanotify.template_id.covid_vaccine_registration
      end

      email_response = notify_client.send_email(email_address: email, template_id: template_id,
                                                personalisation: { 'date' => date, 'confirmation_id' => sid },
                                                reference: sid)
      handle_success(submission, email_response)
    rescue => e
      handle_errors(e, sid)
    end

    def handle_success(submission, email_response)
      submission.email_confirmation_id = email_response.id
      submission.save
      StatsD.increment(STATSD_SUCCESS_NAME)
    end

    def handle_errors(ex, sid)
      log_exception_to_sentry(ex, { sid: sid })
      StatsD.increment(STATSD_ERROR_NAME)

      if ex.respond_to?(:status_code)
        raise ex if ex.status_code.between?(500, 599)
      else
        raise ex
      end
    end
  end
end
