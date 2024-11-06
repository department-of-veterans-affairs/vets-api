# frozen_string_literal: true

class Lighthouse::FailureNotification
  include Sidekiq::Job

  NOTIFY_SETTINGS = Settings.vanotify.services.benefits_management_tools
  MAILER_TEMPLATE_ID = NOTIFY_SETTINGS.template_id.evidence_submission_failure_email

  # retry for one day
  sidekiq_options retry: 14, queue: 'low'
  # Set minimum retry time to ~1 hour
  sidekiq_retry_in do |count, _exception|
    rand(3600..3660) if count < 9
  end

  sidekiq_retries_exhausted do
    ::Rails.logger.info('Lighthouse::FailureNotification email could not be sent')
  end

  def self.notify_client
    VaNotify::Service.new(NOTIFY_SETTINGS.api_key)
  end

  def perform(icn, first_name, filename, date_submitted, date_failed)
    notify_client.send_email(
      recipient_identifier: { id_value: icn, id_type: 'ICN' },
      template_id: MAILER_TEMPLATE_ID,
      personalisation: { first_name:, filename:, date_submitted:, date_failed: }
    )

    ::Rails.logger.info('Lighthouse::FailureNotification email sent')
  rescue => e
    ::Rails.logger.error('Lighthouse::FailureNotification email error',
                         { message: e.message })
  end
end
