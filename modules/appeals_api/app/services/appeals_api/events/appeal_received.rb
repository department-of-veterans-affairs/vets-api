# frozen_string_literal: true

module AppealsApi
  module Events
    class AppealReceived
      def initialize(opts)
        @opts = opts
        raise InvalidKeys unless required_keys?
      end

      def hlr_received
        return unless Flipper.enabled?(:decision_review_hlr_email)

        log_error(guid, 'HLR') unless email_identifier

        template_type = 'higher_level_review_received'
        template = { template_id: template_id(template_type) }

        vanotify_service.send_email(params(template))
      end

      private

      attr_accessor :opts

      def vanotify_service
        @vanotify_service ||= VaNotify::Service.new(Settings.vanotify.services.lighthouse.api_key)
      end

      def params(template_id)
        [
          lookup,
          template_id,
          personalisation
        ].reduce(&:merge)
      end

      def lookup
        if opts['email_identifier'] == 'email'
          {
            email_address: opts['email_identifier']['id_value']
          }
        else
          {
            recipient_identifier: {
              id_value: opts['email_identifier']['id_value'],
              id_type: opts['email_identifier']['id_type']
            }
          }
        end
      end

      def template_id(template)
        Settings.vanotify.services.lighthouse.template_id.public_send(template)
      end

      def personalisation
        {
          'first_name' => opts['first_name'],
          'date_submitted' => opts['date_submitted'].strftime('%B %d, %Y')
        }
      end

      def log_error(guid, type)
        Rails.logger.error "No lookup value present for AppealsApi::AppealReceived notification #{type} - GUID: #{guid}"
      end

      def guid
        opts['guid']
      end

      def email_identifier
        opts['email_identifier']
      end

      def required_keys?
        required_keys.all? { |k| opts.key?(k) }
      end

      def required_keys
        %w[guid email_identifier date_submitted first_name]
      end
    end

    class InvalidKeys < StandardError; end
  end
end
