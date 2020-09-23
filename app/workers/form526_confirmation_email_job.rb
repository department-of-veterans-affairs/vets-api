# frozen_string_literal: true

require 'sentry_logging'
require 'va_notify/service'

class Form526ConfirmationEmailJob
  include Sidekiq::Worker
  include SentryLogging
  sidekiq_options expires_in: 1.day

  STATSD_ERROR_NAME = 'worker.form526_confirmation_email.error'
  STATSD_SUCCESS_NAME = 'worker.form526_confirmation_email.success'

  def perform(personalization_parameters)
    @notify_client ||= VaNotify::Service.new
    @notify_client.send_email(
      email_address: personalization_parameters['email'],
      template_id: Settings.vanotify.template_id.form526_confirmation_email,
      personalisation: {
        'claim_id' => personalization_parameters['submitted_claim_id'],
        'date_submitted' => personalization_parameters['date_submitted'],
        'full_name' => personalization_parameters['full_name']
      }
    )
    StatsD.increment(STATSD_SUCCESS_NAME)
  rescue => e
    handle_errors(e)
  end

  def handle_errors(ex)
    log_exception_to_sentry(ex)
    StatsD.increment(STATSD_ERROR_NAME)

    raise ex if ex.status_code.between?(500, 599)
  end
end
