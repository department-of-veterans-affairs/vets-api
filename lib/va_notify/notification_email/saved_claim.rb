# frozen_string_literal: true

module VANotify
  module NotificationEmail

    STATSD = 'api.va_notify.notification_email'

    CONFIRMATION = :confirmation
    ERROR = :error
    RECEIVED = :received

    # error indicating failure to send email
    class FailureToSend < StandardError; end

    class SavedClaim

      def initialize(saved_claim, service_name: nil)
        @claim = saved_claim
        @service_name = service_name
      end

      def send(type, at: nil)
        config = Settings.vanotify.services[service_name]
        config = config&.email[type]
        raise ArgumentError, "Invalid service '#{service_name}' or type '#{type}'" unless config

        email_template_id = able_to_send?(config)
        return unless email_template_id

        if at
          VANotify::EmailJob.perform_at(
            at,
            email,
            email_template_id,
            personalization
          )
        else
          VANotify::EmailJob.perform_async(
            email,
            email_template_id,
            personalization
          )
        end

        claim.insert_notification(config.template_id)
      rescue => e
        metric = "#{VANotify::NotificationEmail::STATSD}.failure"

        tags = ["service_name:#{service_name}", "form_id:#{claim.form_id}", "email_template_id:#{email_template_id}"]
        StatsD.increment(metric, tags:)

        payload = {
          statsd: metric,
          form_id: claim.form_id,
          saved_claim_id: claim.id
          service_name:
          email_template_id:
          message: e&.message
        }
        Rails.logger.error('VANotify::NotificationEmail#send failure!', **payload)
      end

      private

      attr_reader :claim

      def service_name
        @service_name ||= claim.form_id.downcase.gsub(/-/, '_')
      end

      def flipper?(flipper_id)
        !flipper_id || (flipper_id && Flipper.enabled?(:"#{flipper_id}"))
      end

      def able_to_send?(email_config)
        raise FailureToSend, 'Invalid configuration' if !email_config.template_id
        raise FailureToSend, 'Missing email' if email.blank?
        raise FailureToSend, 'Notification already sent' if claim.va_notification?(config.template_id)

        email_config.template_id if flipper?(email_config.flipper)
      end

      def email
        claim.email
      end

      def first_name
        claim.parsed_form.dig('veteranFullName', 'first')
      end

      def personalization
        {
          'first_name' => first_name&.titleize,
          'date_submitted' => claim.submitted_at,
          'confirmation_number' => claim.confirmation_number,
        }
      end

    end
  end
end
