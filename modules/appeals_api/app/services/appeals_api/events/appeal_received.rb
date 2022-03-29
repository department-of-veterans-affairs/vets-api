# frozen_string_literal: true

module AppealsApi
  module Events
    class AppealReceived
      def initialize(opts)
        @opts = opts
        raise InvalidKeys, 'AppealReceived: Missing required keys' unless required_keys?
      end

      def hlr_received
        return unless Flipper.enabled?(:decision_review_hlr_email)

        unless valid_email_identifier?
          log_error(guid, 'HLR')
          raise InvalidKeys, 'Invalid email identifier'
        end

        template_type = 'higher_level_review_received'
        template = { template_id: template_id(template_type) }

        vanotify_service.send_email(params(template))
      end

      def nod_received
        return unless Flipper.enabled?(:decision_review_nod_email)

        unless valid_email_identifier?
          log_error(guid, 'NOD')
          raise InvalidKeys, 'Invalid email identifier'
        end

        template_type = +'notice_of_disagreement_received'
        template = { template_id: template_id(template_type) }

        vanotify_service.send_email(params(template))
      end

      def sc_received
        return unless Flipper.enabled?(:decision_review_sc_email)

        unless valid_email_identifier?
          log_error(guid, 'SC')
          raise InvalidKeys, 'Invalid email identifier'
        end

        template_type = 'supplemental_claim_received'
        template = { template_id: template_id(template_type) }

        vanotify_service.send_email(params(template))
      end

      private

      attr_accessor :opts

      def vanotify_service
        @vanotify_service ||= VaNotify::Service.new(Settings.vanotify.services.lighthouse.api_key)
      end

      def params(template_opts)
        [
          lookup,
          template_opts,
          personalisation
        ].reduce(&:merge)
      end

      def lookup
        return { email_address: opts['claimant_email'] } if opts['claimant_email']

        if opts['email_identifier']['id_type'] == 'email'
          { email_address: opts['email_identifier']['id_value'] }
        else
          { recipient_identifier: { id_value: opts['email_identifier']['id_value'],
                                    id_type: opts['email_identifier']['id_type'] } }
        end
      end

      def template_id(template)
        t = claimant? ? "#{template}_claimant" : template
        Settings.vanotify.services.lighthouse.template_id.public_send(t)
      end

      def personalisation
        p = { 'date_submitted' => date_submitted }
        if claimant?
          p['first_name'] = opts['claimant_first_name']
          p['veterans_name'] = opts['first_name']
        else
          p['first_name'] = opts['first_name']
        end
        { personalisation: p }
      end

      def log_error(guid, type)
        Rails.logger.error "No lookup value present for AppealsApi::AppealReceived notification #{type} - GUID: #{guid}"
      end

      def guid
        opts['guid']
      end

      def date_submitted
        @date_submitted ||= DateTime.iso8601(opts['date_submitted']).strftime('%B %d, %Y')
      end

      def valid_email_identifier?
        if claimant?
          opts['claimant_email'].present?
        else
          required_email_identifier_keys.all? { |k| opts.dig('email_identifier', k).present? }
        end
      end

      def claimant?
        opts['claimant_first_name'].present? || opts['claimant_email'].present?
      end

      def required_email_identifier_keys
        %w[id_type id_value]
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
