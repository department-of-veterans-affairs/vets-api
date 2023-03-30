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

    def perform(record_id)
      submission = CovidVaccine::V0::ExpandedRegistrationSubmission.find(record_id)
      return if submission.email_confirmation_id.present?

      notify_client = VaNotify::Service.new(Settings.vanotify.services.va_gov.api_key)
      template_id = Settings.vanotify.services.va_gov.template_id.covid_vaccine_expanded_registration
      email_address = submission.raw_form_data['email_address']

      notify_response = notify_client.send_email(email_address:, template_id:,
                                                 personalisation: { 'date' => formatted_date(submission.created_at),
                                                                    'confirmation_id' => submission.submission_uuid },
                                                 reference: submission.submission_uuid)
      handle_success(submission, notify_response)
    rescue => e
      handle_errors(e, record_id)
    end

    def handle_success(submission, notify_response)
      submission.update!(email_confirmation_id: notify_response.id)
      StatsD.increment(STATSD_SUCCESS_NAME)
    end

    def handle_errors(ex, record_id)
      log_exception_to_sentry(ex, { record_id: })
      StatsD.increment(STATSD_ERROR_NAME)

      if ex.respond_to?(:status_code)
        raise ex if ex.status_code.between?(500, 599)
      else
        raise ex
      end
    end

    private

    def formatted_date(created_at)
      created_at.strftime('%B %-d, %Y %-l:%M %P %Z').sub(/([ap])m/, '\1.m.')
    end
  end
end
