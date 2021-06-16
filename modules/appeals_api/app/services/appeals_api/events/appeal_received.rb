# frozen_string_literal: true

module AppealsApi
  module Events
    class AppealReceived
      def initialize(opts)
        @opts = opts
        raise InvalidKeys unless required_keys?
      end

      def higher_level_review
        log_error unless email

        template_type = 'higher_level_review_received'
        template_id = template_id(template_type)

        vanotify_service.send_email(
        email_address: email,
          template_id: template_id
        )
      end

      private

      attr_accessor :opts

      def vanotify_service
        @vanotify_service ||= VaNotify::Service.new(Settings.vanotify.services.lighthouse.api_key)
      end

      def template_id(template)
        Settings.vanotify.services.va_gov.template_id.public_send(template)
      end

      def log_error
        Rails.logger.error 'No email present for AppealsApi::AppealReceived notification'
      end

      def email
        opts['email']
      end

      def required_keys?
        required_keys.all? { |k| opts.key?(k) }
      end

      def required_keys
        %w[email]
      end
    end

    class InvalidKeys < StandardError; end
  end
end
