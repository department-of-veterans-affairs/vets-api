# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'jwt'
require_relative 'configuration'
require_relative 'error'
require 'vets/shared_logging'

module VaNotify
  # Client for VA Notify Push Notification API
  class Client < Common::Client::Base
    include Common::Client::Concerns::Monitoring
    include Vets::SharedLogging

    configuration VaNotify::Configuration

    STATSD_KEY_PREFIX = 'api.vanotify'
    # Expected API key format: 'test-key-{service_id}-{secret_token}'
    # The service_id and secret_token are UUIDs (36 chars each), separated by a dash.
    # Example: 'test-key-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
    SERVICE_ID_LENGTH = 36
    SECRET_TOKEN_LENGTH = 36
    SERVICE_ID_OFFSET = SERVICE_ID_LENGTH + SECRET_TOKEN_LENGTH + 1

    attr_reader :api_key, :service_id, :secret_token, :callback_options, :template_id

    def initialize(api_key, callback_options = {})
      super()
      @api_key = api_key
      @callback_options = callback_options || {}

      # Offsets are based on the format: 'test-key-' (9 chars) + service_id (36) + '-' (1) + secret_token (36)
      @service_id = api_key[(api_key.length - SERVICE_ID_OFFSET)..(api_key.length - SECRET_TOKEN_LENGTH - 2)]
      @secret_token = api_key[(api_key.length - SECRET_TOKEN_LENGTH)..api_key.length]

      validate_tokens!
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

      # Add callback URL if request-level callbacks are enabled
      payload = args.dup
      with_monitoring do
        response = perform(:post, 'v2/notifications/push', payload.to_json, auth_headers)
        # Parse the response body if it's a Faraday::Env object
        response_body = response.is_a?(Faraday::Env) ? response.body : response
        response_body
      end
    rescue => e
      handle_error(e)
    end

    private

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
      # Validate using Notifications::UuidValidator from notifications-ruby-client gem
      Notifications::UuidValidator.validate!(service_id, 'Invalid service_id format in API key')
      Notifications::UuidValidator.validate!(secret_token, 'Invalid secret_token format in API key')
    end

    def handle_error(error)
      case error
      when Common::Client::Errors::ClientError
        log_error_details(error)
        if error.status >= 400
          context = {
            template_id:,
            callback_metadata: sanitize_metadata(
              callback_options[:callback_metadata] || callback_options['callback_metadata']
            )
          }
          raise VANotify::Error.from_generic_error(error, context)
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

    def log_error_details(error)
      log_message_to_rails(error.message, 'error', { url: config.base_path, body: error.try(:body) })
    end
  end
end
