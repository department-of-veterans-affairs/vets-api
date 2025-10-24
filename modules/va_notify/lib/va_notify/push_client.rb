# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'jwt'
require_relative 'configuration'
require_relative 'error'

module VaNotify
  # Client for VA Notify Push Notification API
  class PushClient < Common::Client::Base
    include Common::Client::Concerns::Monitoring

    configuration VaNotify::Configuration

    STATSD_KEY_PREFIX = 'api.vanotify'

    attr_reader :api_key, :service_id, :secret_token, :callback_options, :template_id

    def initialize(api_key, callback_options = {})
      @api_key = api_key
      @callback_options = callback_options || {}

      # Extract service_id and secret_token from API key (similar to Notifications::Client::Speaker)
      @service_id = api_key[(api_key.length - 73)..(api_key.length - 38)]
      @secret_token = api_key[(api_key.length - 36)..api_key.length]

      # validate_tokens!
    end

    # Send push notification
    #
    # @param args [Hash] Push notification parameters
    # @option args [String] :mobile_app The mobile app identifier (e.g., 'VA_FLAGSHIP_APP')
    # @option args [String] :template_id The notification template ID
    # @option args [Hash] :recipient_identifier Hash containing :id_type and :id_value
    # @option args [Hash] :personalisation Optional personalisation data for the template
    # @return [Hash] Response from VA Notify API
    def send_push(args)
      @template_id = args[:template_id]

      payload = build_payload(args)

      with_monitoring do
        response = perform(:post, 'v2/notifications/push', payload, auth_headers)
        # Parse the response body if it's a Faraday::Env object
        response_body = response.is_a?(Faraday::Env) ? response.body : response
        response_body
      end
    rescue => e
      handle_error(e)
    end

    private

    def build_payload(args)
      payload = {
        mobile_app: args[:mobile_app],
        template_id: args[:template_id],
        recipient_identifier: {
          id_type: args[:recipient_identifier][:id_type],
          id_value: args[:recipient_identifier][:id_value]
        }
      }

      # Add personalisation if provided
      payload[:personalisation] = args[:personalisation] if args[:personalisation]

      # Add callback URL if request-level callbacks are enabled
      payload[:callback_url] = Settings.vanotify.callback_url if Flipper.enabled?(:va_notify_request_level_callbacks)

      # Convert to JSON string for HTTP request body
      payload.to_json
    end

    def auth_headers
      {
        'Authorization' => "Bearer #{jwt_token}",
        'Content-Type' => 'application/json',
        'User-Agent' => 'vets-api-push-client'
      }
    end

    def jwt_token
      payload = {
        iss: service_id,
        iat: Time.now.to_i
      }
      JWT.encode(payload, secret_token, 'HS256')
    end

    def validate_tokens!
      # Basic validation similar to Notifications::Client::Speaker
      raise ArgumentError, 'Invalid API key format' if service_id.nil? || secret_token.nil?
      raise ArgumentError, 'Invalid service_id length' unless service_id.length == 36
      raise ArgumentError, 'Invalid secret_token length' unless secret_token.length == 36
    end

    def handle_error(error)
      case error
      when Common::Client::Errors::ClientError
        save_error_details(error)
        if Flipper.enabled?(:va_notify_custom_errors) && error.status >= 400
          context = {
            template_id:,
            callback_metadata: sanitize_metadata(
              callback_options[:callback_metadata] || callback_options['callback_metadata']
            )
          }
          raise VANotify::Error.from_generic_error(error, context)
        elsif error.status >= 400
          raise_backend_exception("VANOTIFY_PUSH_#{error.status}", self.class, error)
        end
      else
        raise error
      end
    end

    def sanitize_metadata(metadata)
      return nil unless metadata.is_a?(Hash)

      # Specific keys that are safe to include and do not contain PII
      metadata.slice(:notification_type, :form_number, :mobile_app)
    end

    def save_error_details(error)
      Sentry.set_tags(
        external_service: self.class.to_s.underscore
      )

      Sentry.set_extras(
        url: config.base_path,
        message: error.message,
        body: error.body
      )
    end
  end
end
