# frozen_string_literal: true

require 'va_notify/notification_email'

module VANotify
  module NotificationEmail
    class SavedClaim
      def initialize(saved_claim, service_name: nil)
        @claim = saved_claim
        @vanotify_service = service_name
        @config = Settings.vanotify.services[vanotify_service]
        raise ArgumentError, "Invalid service_name '#{vanotify_service}'" unless config
      end

      def deliver(email_type, at: nil)
        email_config = config&.email[email_type]
        raise ArgumentError, "Invalid email_type '#{email_type}'" unless email_config

        email_template_id = able_to_send?(email_config)
        return unless email_template_id

        at ? enqueue_email(email_template_id, at) : send_email(email_template_id)

        claim.insert_notification(email_config.template_id)
      rescue => e
        tags = ["service_name:#{vanotify_service}", "form_id:#{claim.form_id}",
                "email_template_id:#{email_template_id}"]
        context = {
          form_id: claim.form_id,
          saved_claim_id: claim.id,
          service_name: vanotify_service,
          email_type:,
          email_template_id:
        }
        VANotify::NotificationEmail.monitor_send_failure(e&.message, tags:, context:)
      end

      private

      attr_reader :claim, :config

      def vanotify_service
        @vanotify_service ||= claim.form_id.downcase.gsub(/-/, '_')
      end

      def flipper?(flipper_id)
        !flipper_id || (flipper_id && Flipper.enabled?(:"#{flipper_id}"))
      end

      def able_to_send?(email_config)
        raise VANotify::NotificationEmail::FailureToSend, 'Invalid configuration' unless email_config.template_id
        raise VANotify::NotificationEmail::FailureToSend, 'Missing email' if email.blank?

        if claim.va_notification?(email_config.template_id)
          raise VANotify::NotificationEmail::FailureToSend, 'Notification already sent'
        end

        email_config.template_id if flipper?(email_config.flipper_id)
      end

      def enqueue_email(email_template_id, at)
        VANotify::EmailJob.perform_at(
          at,
          email,
          email_template_id,
          personalization
        )
      end

      def send_email(email_template_id)
        VANotify::EmailJob.perform_async(
          email,
          email_template_id,
          personalization
        )
      end

      def email
        claim.email
      end

      def personalization
        {
          'date_submitted' => claim.submitted_at,
          'confirmation_number' => claim.confirmation_number
        }
      end
    end
  end
end
