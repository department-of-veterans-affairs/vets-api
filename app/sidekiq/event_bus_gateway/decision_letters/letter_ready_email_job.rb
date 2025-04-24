# frozen_string_literal: true

require 'sidekiq'

module EventBusGateway
  module DecisionLetters
    class LetterReadyEmailJob
      include Sidekiq::Job
      include SentryLogging

      # Job should not retry
      sidekiq_options retry: 0
      NOTIFY_SETTINGS = Settings.vanotify.services.benefits_management_tools

      # For now, receive arguments and send the email.
      # Going forward, this will be a recurring job that pulls
      # ready-to-send decision letter emails from the DB
      def perform(participant_id, template_id, personalisation)
        notify_client.send_email(
          recipient_identifier: { id_value: participant_id, id_type: 'ICN' },
          template_id:,
          personalisation:
        )

        # EVENTUAL BEHAVIOR
        # return unless should_perform?

        # send_ready_decision_letter_emails

        # nil
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

      def send_ready_decision_letter_emails
        ready_letters.find_each do |_letter|
          notify_client.send_email(
            recipient_identifier: { id_value: @participant_id, id_type: 'ICN' },
            template_id: @template_id,
            personalisation: @personalisation
          )
        end
      end
    end
  end
end
