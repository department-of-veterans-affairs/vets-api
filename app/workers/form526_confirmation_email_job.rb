# frozen_string_literal: true

require 'notifications/client'

class Form526ConfirmationEmailJob
  include Sidekiq::Worker
  sidekiq_options expires_in: 1.day

  STATSD_ERROR_NAME = 'worker.form526_confirmation_email.error'

  def perform(id, personalization_parameters)
    @notify_client ||= Notifications::Client.new(
      Settings.vanotify.api_key,
      Settings.vanotify.client_url
    )
    @notify_client.send_email(
      email_address: personalization_parameters['email'],
      template_id: Settings.vanotify.template_id.form526_confirmation_email,
      personalisation: {
        'claim_id' => personalization_parameters['submitted_claim_id'],
        'date_submitted' => personalization_parameters['updated_at'],
        'full_name' => personalization_parameters['full_name']
      }
    )
  rescue => e
    Rails.logger.error(
      "Error performing Form526ConfirmationEmailJob: #{e.message}",
      submission_id: id
    )
    StatsD.increment(STATSD_ERROR_NAME)
  end
end
