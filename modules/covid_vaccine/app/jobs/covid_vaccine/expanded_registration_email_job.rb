# frozen_string_literal: true

require 'sentry_logging'
require 'va_notify/service'

module CovidVaccine
  class ExpandedRegistrationEmailJob
    include Sidekiq::Worker
    include SentryLogging
    sidekiq_options expires_in: 1.day, retry: 2

    STATSD_ERROR_NAME = 'worker.covid_vaccine_confirmation_email.error'
    STATSD_SUCCESS_NAME = 'worker.covid_vaccine_confirmation_email.success'

    # submission_id is the CovidVaccine::V0::ExpandedRegistrationSubmission record id, not to be confused with sid
    def perform(submission_id)
      expanded_reg_sub = CovidVaccine::V0::ExpandedRegistrationSubmission.find(submission_id)
      return false if expanded_reg_sub.email_confirmation_id.present?

      notify_client = VaNotify::Service.new(Settings.vanotify.services.va_gov.api_key)
      template_id = Settings.vanotify.services.va_gov.template_id.covid_vaccine_expanded_registration

      email_response = notify_client.send_email(email_address: expanded_reg_sub.email,
                                                template_id: template_id,
                                                personalisation: {
                                                  'date' => expanded_reg_sub.created_at,
                                                  'submission_id' => expanded_reg_sub.id
                                                },
                                                reference: expanded_reg_sub.id)
      handle_success(expanded_reg_sub, email_response)
    rescue => e
      handle_errors(e, expanded_reg_sub.id)
    end

    def handle_success(expanded_reg_sub, email_response)
      expanded_reg_sub.email_confirmation_id = email_response.id
      expanded_reg_sub.save
      StatsD.increment(STATSD_SUCCESS_NAME)
    end

    def handle_errors(ex, submission_id)
      log_exception_to_sentry(ex, { expanded_registration_submission_id: submission_id })
      StatsD.increment(STATSD_ERROR_NAME)

      if ex.respond_to?(:status_code)
        raise ex if ex.status_code.between?(500, 599)
      else
        raise ex
      end
    end
  end
end
