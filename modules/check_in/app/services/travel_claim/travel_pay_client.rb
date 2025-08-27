# frozen_string_literal: true

module TravelClaim
  ##
  # Unified client for all Travel Claim API operations.
  # Consolidates functionality from individual clients into a single interface.
  #
  class TravelPayClient < Common::Client::Base
    EXPENSE_DESCRIPTION = 'mileage'
    TRIP_TYPE = 'RoundTrip'
    GRANT_TYPE = 'client_credentials'

    attr_reader :settings, :redis_client

    def initialize(icn:)
      @current_icn = icn
      @settings = Settings.check_in.travel_reimbursement_api_v2
      @correlation_id = SecureRandom.uuid
      @redis_client = TravelClaim::RedisClient.build
      @current_veis_token = nil
      @current_btsss_token = nil
      super()
    end

    ##
    # Returns the singleton configuration instance for Travel Claim services.
    #
    # @return [TravelClaim::Configuration] The configuration instance
    #
    def config
      TravelClaim::Configuration.instance
    end

    ##
    # Gets a VEIS access token for API authentication.
    #
    # @return [Faraday::Response] HTTP response containing access token
    #
    def veis_token_request
      body = URI.encode_www_form({
                                   client_id: @settings.travel_pay_client_id,
                                   client_secret: @settings.travel_pay_client_secret,
                                   scope: @settings.scope,
                                   grant_type: GRANT_TYPE
                                 })

      headers = { 'Content-Type' => 'application/x-www-form-urlencoded' }

      perform(:post, "/#{@settings.tenant_id}/oauth2/v2.0/token", body, headers)
    end

    ##
    # Gets a system access token for API authentication.
    #
    # @param client_number [String] Client number for BTSSS API calls
    # @param veis_access_token [String] VEIS access token
    # @param icn [String] Patient ICN
    # @return [Faraday::Response] HTTP response containing access token
    #
    def system_access_token_request(client_number:, veis_access_token:, icn:)
      body = { secret: @settings.travel_pay_client_secret, icn: }
      client_number ||= @settings.travel_pay_client_number

      headers = {
        'Content-Type' => 'application/json',
        'X-Correlation-ID' => @correlation_id,
        'BTSSS-API-Client-Number' => client_number.to_s,
        'Authorization' => "Bearer #{veis_access_token}"
      }.merge(subscription_key_headers)

      perform(:post, '/api/v4/auth/system-access-token', body, headers)
    end

    ##
    # Sends a request to find or create an appointment.
    #
    # @param appointment_date_time [String] ISO 8601 formatted appointment date/time
    # @param facility_id [String] VA facility identifier
    # @return [Faraday::Response] HTTP response containing appointment data
    #
    def send_appointment_request(appointment_date_time:, facility_id:)
      with_auth do
        body = {
          appointmentDateTime: appointment_date_time,
          facilityStationNumber: facility_id
        }
        headers = build_standard_headers

        perform(:post, '/api/v3/appointments/find-or-add', body, headers)
      end
    end

    ##
    # Builds environment-specific subscription key headers for API authentication.
    # Production uses separate E and S subscription keys, while other environments
    # use a single subscription key.
    #
    # @return [Hash] Headers hash with appropriate subscription keys
    #
    def subscription_key_headers
      if Settings.vsp_environment == 'production'
        {
          'Ocp-Apim-Subscription-Key-E' => @settings.e_subscription_key,
          'Ocp-Apim-Subscription-Key-S' => @settings.s_subscription_key
        }
      else
        { 'Ocp-Apim-Subscription-Key' => @settings.subscription_key }
      end
    end

    ##
    # Builds standard headers for Travel Claim API requests.
    # Includes content type, authorization, and correlation ID.
    #
    # @return [Hash] Complete headers hash including subscription key headers
    #
    def build_standard_headers
      headers = {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{@current_veis_token}",
        'X-BTSSS-Token' => @current_btsss_token,
        'X-Correlation-ID' => @correlation_id
      }

      headers.merge!(subscription_key_headers)
      headers
    end

    ##
    # Wraps external API calls to ensure proper authentication.
    # Handles token refresh on unauthorized responses.
    #
    # @yield Block containing the API call to make
    # @return [Faraday::Response] API response
    #
    def with_auth
      raise ArgumentError, 'ICN not set' if @current_icn.blank?

      ensure_tokens!
      yield
    rescue Common::Exceptions::BackendServiceException => e
      if e.original_status == 401
        refresh_tokens!
        yield
      else
        raise
      end
    end

    ##
    # Ensures valid tokens are available.
    # Fetches tokens from Redis cache or fetches new ones if needed.
    #
    def ensure_tokens!
      return if @current_veis_token && @current_btsss_token

      # Try to get tokens from Redis first
      cached_veis = @redis_client.token
      cached_btsss = @redis_client.v4_token(cache_key: "btsss_#{@current_icn}")
      if cached_veis && cached_btsss
        @current_veis_token = cached_veis
        @current_btsss_token = cached_btsss
        return
      end

      fetch_tokens!
    end

    ##
    # Fetches fresh tokens.
    # Updates internal token state and stores in Redis.
    #
    def fetch_tokens!
      # Get VEIS token
      veis_response = veis_token_request
      @current_veis_token = veis_response.body['access_token']

      # Get BTSSS token
      btsss_response = system_access_token_request(
        client_number: nil,
        veis_access_token: @current_veis_token,
        icn: @current_icn
      )
      @current_btsss_token = btsss_response.body['access_token']

      # Store tokens in Redis
      @redis_client.save_token(token: @current_veis_token)
      @redis_client.save_v4_token(cache_key: "btsss_#{@current_icn}", token: @current_btsss_token)
    end

    ##
    # Refreshes tokens.
    # Clears current tokens and Redis cache, then fetches new ones.
    #
    def refresh_tokens!
      @current_veis_token = nil
      @current_btsss_token = nil

      # Clear tokens from Redis
      @redis_client.save_token(token: nil)
      @redis_client.save_v4_token(cache_key: "btsss_#{@current_icn}", token: nil)

      fetch_tokens!
    end
  end
end
