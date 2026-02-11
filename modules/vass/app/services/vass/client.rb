# frozen_string_literal: true

require 'forwardable'
require 'vass/errors'

module Vass
  ##
  # Client for interacting with the VASS (Veterans Appointment Scheduling System) API.
  #
  # Supports OAuth authentication with Microsoft identity provider and provides
  # methods for all VASS API endpoints including appointment availability,
  # agent skills, veteran data retrieval, and appointment management.
  #
  class Client < Common::Client::Base
    extend Forwardable
    include Common::Client::Concerns::Monitoring
    include Vass::Logging

    GRANT_TYPE = 'client_credentials'
    STATSD_KEY_PREFIX = 'api.vass'

    attr_reader :settings

    def_delegators :settings, :auth_url, :tenant_id, :client_id, :client_secret, :scope,
                   :api_url, :subscription_key, :service_name

    ##
    # @param correlation_id [String, nil] Correlation ID for request tracing
    #
    def initialize(correlation_id: nil)
      @correlation_id = correlation_id || SecureRandom.uuid
      @settings = Settings.vass
      super()
    end

    ##
    # Returns the singleton configuration instance for VASS services.
    #
    # @return [Vass::Configuration] The configuration instance
    #
    def config
      Vass::Configuration.instance
    end

    # ------------ Authentication ------------

    ##
    # Gets an OAuth access token from Microsoft identity provider.
    #
    # @return [Faraday::Response] HTTP response containing access token
    #
    def oauth_token_request
      with_monitoring do
        body = URI.encode_www_form({
                                     client_id:,
                                     client_secret:,
                                     scope:,
                                     grant_type: GRANT_TYPE
                                   })

        headers = { 'Content-Type' => 'application/x-www-form-urlencoded' }
        perform(:post, "#{tenant_id}/oauth2/v2.0/token", body, headers, { server_url: auth_url })
      end
    end

    # ------------ VASS API Methods ------------

    ##
    # Retrieves appointment availability based on provided criteria.
    #
    # @param edipi [String] Veteran EDIPI
    # @param availability_request [Hash] Appointment availability request data
    # @return [Faraday::Response] HTTP response containing availability data
    #
    def get_appointment_availability(edipi:, availability_request:)
      with_auth do
        with_monitoring do
          headers = default_headers.merge('EDIPI' => edipi)
          perform(:post, 'api/AppointmentAvailability', availability_request, headers)
        end
      end
    end

    ##
    # Cancels an existing appointment.
    #
    # @param edipi [String] Veteran EDIPI
    # @param appointment_id [String] Appointment ID to cancel
    # @return [Faraday::Response] HTTP response confirming cancellation
    #
    def cancel_appointment(edipi:, appointment_id:)
      with_auth do
        with_monitoring do
          headers = default_headers.merge('EDIPI' => edipi)
          cancel_request = { appointmentId: appointment_id }
          perform(:post, 'api/CancelAppointment', cancel_request, headers)
        end
      end
    end

    ##
    # Retrieves available agent skills for appointment scheduling.
    #
    # @return [Faraday::Response] HTTP response containing agent skills data
    #
    def get_agent_skills
      with_auth do
        with_monitoring do
          perform(:get, 'api/GetAgentSkills', nil, default_headers)
        end
      end
    end

    ##
    # Retrieves veteran information by veteran ID.
    #
    # Used in the OTP flow where we only have the UUID from the welcome email.
    # The VASS API returns EDIPI in the response, so it's not required in the request.
    #
    # @param veteran_id [String] Veteran ID (UUID) in VASS system
    # @return [Faraday::Response] HTTP response containing veteran data including EDIPI
    #
    def get_veteran(veteran_id:)
      with_auth do
        with_monitoring do
          headers = default_headers.merge('veteranId' => veteran_id)
          perform(:get, 'api/GetVeteran', nil, headers)
        end
      end
    end

    ##
    # Retrieves a specific veteran appointment.
    #
    # @param edipi [String] Veteran EDIPI
    # @param appointment_id [String] Appointment ID
    # @return [Faraday::Response] HTTP response containing appointment data
    #
    def get_veteran_appointment(edipi:, appointment_id:)
      with_auth do
        with_monitoring do
          headers = default_headers.merge('EDIPI' => edipi, 'appointmentId' => appointment_id)
          perform(:get, 'api/GetVeteranAppointment', nil, headers)
        end
      end
    end

    ##
    # Retrieves all appointments for a veteran.
    #
    # @param edipi [String] Veteran EDIPI
    # @param veteran_id [String] Veteran ID in VASS system
    # @return [Faraday::Response] HTTP response containing appointments data
    #
    def get_veteran_appointments(edipi:, veteran_id:)
      with_auth do
        with_monitoring do
          headers = default_headers.merge('EDIPI' => edipi)
          body = {
            'correlationId' => @correlation_id,
            'veteranId' => veteran_id
          }
          perform(:post, 'api/GetVeteranAppointments', body, headers)
        end
      end
    end

    ##
    # Saves/creates a new appointment.
    #
    # @param edipi [String] Veteran EDIPI
    # @param appointment_data [Hash] Appointment creation data
    # @return [Faraday::Response] HTTP response containing created appointment data
    #
    def save_appointment(edipi:, appointment_data:)
      with_auth do
        with_monitoring do
          headers = default_headers.merge('EDIPI' => edipi)
          perform(:post, 'api/SaveAppointment', appointment_data, headers)
        end
      end
    end

    # ------------ Private Methods ------------

    private

    ##
    # Ensures valid OAuth token is available.
    # Fetches token from Redis cache or fetches a new one if needed.
    #
    def ensure_oauth_token!
      return @current_oauth_token if @current_oauth_token.present?

      cached_token = redis_client.token
      if cached_token.present?
        @current_oauth_token = cached_token
      else
        log_vass_event(action: 'oauth_cache_miss', correlation_id: @correlation_id)
        @current_oauth_token = mint_oauth_token
        redis_client.save_token(token: @current_oauth_token)
      end

      @current_oauth_token
    end

    ##
    # Requests a new OAuth token from Microsoft identity provider.
    #
    # @return [String] OAuth access token
    #
    def mint_oauth_token
      resp = oauth_token_request
      token = resp.body['access_token']
      if token.blank?
        log_vass_event(action: 'oauth_token_missing', level: :error, correlation_id: @correlation_id,
                       status: resp.status, has_body: resp.body.present?)
        raise Vass::ServiceException.new('VA900',
                                         { detail: 'OAuth auth missing access_token' }, 502)
      end
      token
    end

    ##
    # Wraps external API calls to ensure proper OAuth authentication.
    # Handles token refresh on unauthorized responses with retry limit.
    #
    # @yield Block containing the API call to make
    # @return [Faraday::Response] API response
    #
    def with_auth
      @auth_retry_attempted = false
      ensure_oauth_token!
      yield
    rescue Vass::ServiceException => e
      if e.original_status == 401 && !@auth_retry_attempted
        @auth_retry_attempted = true
        log_auth_retry
        @current_oauth_token = nil
        ensure_oauth_token!
        yield
      elsif e.original_status == 401 && @auth_retry_attempted
        log_auth_error(e.class.name, e.respond_to?(:original_status) ? e.original_status : nil)
        raise
      else
        raise
      end
    end

    ##
    # Returns default headers required for all VASS API calls.
    #
    # @return [Hash] Default headers hash
    #
    def default_headers
      {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{@current_oauth_token}",
        'correlationId' => @correlation_id
      }.merge(subscription_key_headers)
    end

    ##
    # Builds environment-specific subscription key headers for API authentication.
    #
    # @return [Hash] Headers hash with appropriate subscription keys
    #
    def subscription_key_headers
      { 'Ocp-Apim-Subscription-Key' => subscription_key }
    end

    ##
    # Lazily initializes and returns the Redis client for token caching.
    #
    # @return [Vass::RedisClient] Redis client instance
    #
    def redis_client
      @redis_client ||= Vass::RedisClient.build
    end

    # ------------ Logging helpers ------------

    def log_auth_retry
      log_vass_event(action: 'auth_retry', level: :error, correlation_id: @correlation_id)
    end

    def log_auth_error(error_type, status_code)
      log_vass_event(action: 'auth_failed', level: :error, correlation_id: @correlation_id,
                     error_type:, status_code:)
    end

    ##
    # Override perform method to support server_url option for OAuth authentication
    # at different endpoints than the main API.
    #
    def perform(method, path, params, headers = nil, options = nil)
      server_url = options&.delete(:server_url)
      response_env = if server_url
                       perform_with_custom_connection(server_url, method, path, params,
                                                      { headers:, options: })
                     else
                       super
                     end
      validate_response_body(response_env) unless server_url
      response_env
    rescue Common::Exceptions::BackendServiceException, Common::Client::Errors::ClientError,
           Common::Exceptions::GatewayTimeout, Timeout::Error, Faraday::TimeoutError,
           Faraday::ClientError, Faraday::ServerError, Faraday::Error => e
      handle_error(e)
    end

    def perform_with_custom_connection(server_url, method, path, params, request_config)
      config.connection(server_url:).send(method.to_sym, path, params || {}) do |request|
        request.headers.update(request_config[:headers] || {})
        (request_config[:options] || {}).each { |option, value| request.options.send("#{option}=", value) }
      end.env
    end

    ##
    # Validates the response body structure from VASS API.
    #
    # @param response_env [Faraday::Env] Faraday response environment
    # @raise [Vass::ServiceException] if body indicates failure
    #
    def validate_response_body(response_env)
      body = response_env.body
      return if body.is_a?(Hash) && body['success']

      raise config.service_exception.new(
        Vass::Errors::ERROR_KEY_VASS_ERROR,
        { detail: 'VASS API returned an unsuccessful response' },
        response_env.status,
        body
      )
    end

    ##
    # Normalizes all exceptions to config.service_exception for consistent error handling.
    #
    # @param error [Exception] The exception to normalize
    # @raise [Vass::ServiceException] Always raises config.service_exception
    #
    def handle_error(error)
      exception_class = config.service_exception
      return raise error if error.is_a?(exception_class)

      key, response_values, status, body = normalize_error(error)
      raise exception_class.new(key, response_values, status, body)
    end

    def normalize_error(error)
      case error
      when Common::Exceptions::BackendServiceException
        key = error.key || Vass::Errors::ERROR_KEY_VASS_ERROR
        [key, error.response_values || {}, error.original_status, error.original_body]
      when Common::Client::Errors::ClientError
        [Vass::Errors::ERROR_KEY_CLIENT_ERROR, { detail: error.message }, error.status || 502, error.body]
      when Common::Exceptions::GatewayTimeout, Timeout::Error, Faraday::TimeoutError
        [Vass::Errors::ERROR_KEY_TIMEOUT, { detail: 'Request timeout' }, 504, nil]
      when Faraday::ClientError, Faraday::ServerError, Faraday::Error
        response_hash = error.response&.to_hash
        status = response_hash&.dig(:status) || 502
        [Vass::Errors::ERROR_KEY_CLIENT_ERROR, { detail: error.message }, status, response_hash&.dig(:body)]
      else
        [Vass::Errors::ERROR_KEY_VASS_ERROR, { detail: error.message }, 502, nil]
      end
    end
  end
end
