# frozen_string_literal: true

require 'sidekiq'

module EventBusGateway
  class LetterReadyEmailJob
    include Sidekiq::Job
    include SentryLogging

    # Job should not retry
    sidekiq_options retry: 0
    NOTIFY_SETTINGS = Settings.vanotify.services.event_bus_gateway
    MAILER_TEMPLATE_ID = NOTIFY_SETTINGS.template_id.decision_letter_ready_email

    # For now, receive arguments and send the email.
    # Going forward, this will be a recurring job that pulls
    # ready-to-send decision letter emails from the DB

    # EVENTUAL BEHAVIOR
    # return unless should_perform?

    # send_ready_decision_letter_emails

    # nil
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

    def should_perform?
      ready_letters.present?
    end

    def ready_letters
      @ready_letters ||= NameOfModel.scope
    end

    def notify_client
      VaNotify::Service.new(NOTIFY_SETTINGS.api_key)
    end

    # def send_ready_decision_letter_emails
    #   ready_letters.find_each do |letter|
    #     response = notify_client.send_email(
    #       recipient_identifier: { id_value: @participant_id, id_type: 'ICN' },
    #       template_id: @template_id,
    #       personalisation: @personalisation
    #     )
    #     record_email_send_success(letter, response)
    #   rescue => e
    #     record_email_send_failure(letter, e)
    #   end

    #   nil
    # end

    # def record_email_send_success(letter, error)
    #   # Update the letter as sent, do more logging
    # end

    def record_email_send_failure(error)
      error_message = 'LetterReadyEmailJob VANotify errored'
      ::Rails.logger.error(error_message, { message: error.message })
      StatsD.increment('event_bus_gateway', tags: ['service:event-bus-gateway', "function: #{error_message}"])
      log_exception_to_sentry(error)
    end
  end
end
