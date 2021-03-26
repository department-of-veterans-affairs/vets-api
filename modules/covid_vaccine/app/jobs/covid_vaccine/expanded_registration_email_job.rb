# frozen_string_literal: true

require 'sentry_logging'
require 'va_notify/service'

module CovidVaccine
  class ExpandedRegistrationEmailJob
    include Sidekiq::Worker
    include SentryLogging
    sidekiq_options expires_in: 1.day, retry: 2

    STATSD_ERROR_NAME = 'worker.covid_vaccine_expanded_registration_email.error'
    STATSD_SUCCESS_NAME = 'worker.covid_vaccine_expanded_registration_email.success'

    def perform(record_id, email, datestring)
      submission = CovidVaccine::V0::ExpandedRegistrationSubmission.find_by(id: record_id)
      if submission.nil?
        log_message_to_sentry('No Record found!', :warn, { record_id: record_id, email: email })
        return
      end
      return if submission.email_confirmation_id.present?

      notify_client ||= VaNotify::Service.new(Settings.vanotify.services.va_gov.api_key)
      template_id ||= Settings.vanotify.services.va_gov.template_id.covid_vaccine_registration

      notify_response = notify_client.send_email(email_address: email, template_id: template_id,
                                                 personalisation: { 'date' => datestring,
                                                                    'confirmation_id' => submission.submission_uuid },
                                                 reference: submission.submission_uuid)
      handle_success(submission, notify_response)
    rescue => e
      handle_errors(e, submission.submission_uuid)
    end

    def handle_success(submission, notify_response)
      submission.update!(email_confirmation_id: notify_response.id)
      StatsD.increment(STATSD_SUCCESS_NAME)
    end

    def handle_errors(ex, submission_uuid)
      log_exception_to_sentry(ex, { submission_uuid: submission_uuid })
      StatsD.increment(STATSD_ERROR_NAME)

      if ex.respond_to?(:status_code)
        raise ex if ex.status_code.between?(500, 599)
      else
        raise ex
      end
    end
  end
end
