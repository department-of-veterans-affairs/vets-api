# frozen_string_literal: true

require 'sidekiq'

module EventBusGateway
  class LetterReadyEmailJob
    include Sidekiq::Job
    include SentryLogging

    sidekiq_options retry: 0
    NOTIFY_SETTINGS = Settings.vanotify.services.benefits_management_tools
    MAILER_TEMPLATE_ID = NOTIFY_SETTINGS.template_id.decision_letter_ready_email

    def perform(participant_id, template_id, personalisation)
      notify_client.send_email(
        recipient_identifier: { id_value: participant_id, id_type: 'ICN' },
        template_id:,
        personalisation:
      )
    rescue => e
      record_email_send_failure(e)
    end

    private

    def notify_client
      VaNotify::Service.new(NOTIFY_SETTINGS.api_key)
    end

    def record_email_send_failure(error)
      error_message = 'LetterReadyEmailJob VANotify errored'
      ::Rails.logger.error(error_message, { message: error.message })
      StatsD.increment('event_bus_gateway', tags: ['service:event-bus-gateway', "function: #{error_message}"])
      log_exception_to_sentry(error)
    end
  end
end
