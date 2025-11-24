# frozen_string_literal: true

require 'forwardable'

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
    # @param edipi [String] Veteran EDIPI
    # @param veteran_id [String] Veteran ID in VASS system
    # @return [Faraday::Response] HTTP response containing veteran data
    #
    def get_veteran(edipi:, veteran_id:)
      with_auth do
        with_monitoring do
          headers = default_headers.merge(
            'EDIPI' => edipi,
            'veteranId' => veteran_id
          )
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
        Rails.logger.debug('VassClient OAuth token from cache', correlation_id: @correlation_id)
      else
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
        Rails.logger.error('VassClient OAuth token response missing access_token', {
          correlation_id: @correlation_id,
          status: resp.status,
          has_body: resp.body.present?,
          body_keys: resp.body&.keys
        })
        raise Common::Exceptions::BackendServiceException.new('VA900',
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
    rescue Common::Exceptions::BackendServiceException => e
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
      Rails.logger.error('VassClient 401 error - retrying authentication', correlation_id: @correlation_id)
    end

    def log_auth_error(error_type, status_code)
      Rails.logger.error('VassClient authentication failed', {
                           correlation_id: @correlation_id,
                           error_type:,
                           status_code:
                         })
    end
  end
end
