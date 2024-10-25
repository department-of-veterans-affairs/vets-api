# frozen_string_literal: true

require 'va_notify/notification_email'

require 'pry-byebug'

module VANotify
  module NotificationEmail
    class SavedClaim
      def initialize(saved_claim, service_name: nil)
        @claim = saved_claim
        @vanotify_service = service_name
      end

      def deliver(email_type, at: nil)
        email_template_id = valid_attempt?(email_type)
        return unless email_template_id

        at ? enqueue_email(email_template_id, at) : send_email(email_template_id)

        db_record = claim.insert_notification(email_template_id)
        tags, context = monitoring(email_type)
        VANotify::NotificationEmail.monitor_deliver_success(tags:, context:)

        db_record
      rescue => e
        tags, context = monitoring(email_type)
        VANotify::NotificationEmail.monitor_send_failure(e&.message, tags:, context:)
      end

      private

      attr_reader :claim, :email_template_id

      def vanotify_service
        @vanotify_service ||= claim.form_id.downcase.gsub(/-/, '_')
      end

      def flipper_enabled?(flipper_id)
        !flipper_id || (flipper_id && Flipper.enabled?(:"#{flipper_id}"))
      end

      def valid_attempt?(email_type)
        config = Settings.vanotify.services[vanotify_service]
        raise ArgumentError, "Invalid service_name '#{vanotify_service}'" unless config

        email_config = config.email[email_type]
        raise ArgumentError, "Invalid email_type '#{email_type}'" unless email_config

        @email_template_id = email_config.template_id
        raise VANotify::NotificationEmail::FailureToSend, 'Invalid template' unless email_template_id
        raise VANotify::NotificationEmail::FailureToSend, 'Missing email' if email.blank?

        is_enabled = flipper_enabled?(email_config.flipper_id)
        already_sent = claim.va_notification?(email_config.template_id)
        if already_sent
          tags, context = monitoring(email_type)
          VANotify::NotificationEmail.monitor_duplicate_attempt(tags:, context:)
        end

        email_template_id if is_enabled && !already_sent
      end

      def monitoring(email_type)
        tags = ["service_name:#{vanotify_service}",
                "form_id:#{claim.form_id}",
                "email_template_id:#{email_template_id}"]
        context = {
          form_id: claim.form_id,
          saved_claim_id: claim.id,
          service_name: vanotify_service,
          email_type:,
          email_template_id:
        }
        [tags, context]
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
