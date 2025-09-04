# frozen_string_literal: true

require 'forwardable'

module TravelClaim
  ##
  # Unified client for all Travel Claim API operations.
  # Consolidates functionality from individual clients into a single interface.
  #
  class TravelPayClient < Common::Client::Base
    extend Forwardable

    EXPENSE_DESCRIPTION = 'mileage'
    TRIP_TYPE = 'RoundTrip'
    GRANT_TYPE = 'client_credentials'
    CLIENT_TYPE = '1'
    CLAIM_NAME = 'Travel Reimbursement'
    CLAIMANT_TYPE = 'Veteran'

    attr_reader :redis_client, :settings

    # Delegate settings methods directly to the settings object
    def_delegators :settings, :auth_url, :tenant_id, :travel_pay_client_id, :travel_pay_client_secret,
                   :scope, :claims_url_v2, :subscription_key, :e_subscription_key, :s_subscription_key,
                   :travel_pay_client_number, :travel_pay_resource

    def initialize(uuid:, check_in_uuid:, appointment_date_time:)
      @uuid = uuid
      @check_in_uuid = check_in_uuid
      @appointment_date_time = appointment_date_time
      @redis_client = TravelClaim::RedisClient.build
      @settings = Settings.check_in.travel_reimbursement_api_v2
      @correlation_id = SecureRandom.uuid
      @current_veis_token = nil
      @current_btsss_token = nil

      validate_required_arguments
      load_redis_data
      validate_redis_data
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
                                   client_id: travel_pay_client_id,
                                   client_secret: travel_pay_client_secret,
                                   client_type: CLIENT_TYPE,
                                   scope:,
                                   grant_type: GRANT_TYPE,
                                   resource: travel_pay_resource
                                 })

      headers = { 'Content-Type' => 'application/x-www-form-urlencoded' }

      perform(:post, "#{auth_url}/#{tenant_id}/oauth2/token", body, headers)
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
      body = { secret: travel_pay_client_secret, icn: }
      client_number ||= travel_pay_client_number

      headers = {
        'Content-Type' => 'application/json',
        'X-Correlation-ID' => @correlation_id,
        'BTSSS-API-Client-Number' => client_number.to_s,
        'Authorization' => "Bearer #{veis_access_token}"
      }.merge(subscription_key_headers)

      perform(:post, "#{claims_url_v2}/api/v4/auth/system-access-token", body, headers)
    end

    ##
    # Sends a request to find or create an appointment.
    #
    # @return [Faraday::Response] HTTP response containing appointment data
    #
    def send_appointment_request
      with_auth do
        body = {
          appointmentDateTime: @appointment_date_time,
          facilityStationNumber: @station_number
        }

        perform(:post, "#{claims_url_v2}/api/v3/appointments/find-or-add", body, headers)
      end
    end

    # Sends a request to create a new claim.
    #
    # @param appointment_id [String] Appointment ID
    # @return [Faraday::Response] HTTP response containing claim data
    #
    def send_claim_request(appointment_id:)
      with_auth do
        body = {
          appointmentId: appointment_id,
          claimName: CLAIM_NAME,
          claimantType: CLAIMANT_TYPE
        }

        perform(:post, "#{claims_url_v2}/api/v3/claims", body, headers)
      end
    end

    ##
    # Sends a request to add a mileage expense to a claim.
    #
    # @param claim_id [String] Claim ID
    # @param date_incurred [String] Date expense was incurred (YYYY-MM-DD)
    # @return [Faraday::Response] HTTP response containing expense data
    #
    def send_mileage_expense_request(claim_id:, date_incurred:)
      with_auth do
        body = {
          claimId: claim_id,
          dateIncurred: date_incurred,
          description: EXPENSE_DESCRIPTION,
          tripType: TRIP_TYPE
        }

        perform(:post, "#{claims_url_v2}/api/v3/expenses/mileage", body, headers)
      end
    end

    ##
    # Sends a request to get a claim by ID.
    #
    # @param claim_id [String] Claim ID
    # @return [Faraday::Response] HTTP response containing claim data
    #
    def send_get_claim_request(claim_id:)
      with_auth do
        perform(:get, "#{claims_url_v2}/api/v3/claims/#{claim_id}", nil, headers)
      end
    end

    ##
    # Sends a request to submit a claim for processing.
    #
    # @param claim_id [String] Claim ID
    # @return [Faraday::Response] HTTP response containing submission data
    #
    def send_claim_submission_request(claim_id:)
      with_auth do
        body = { claimId: claim_id }
        perform(:patch, "#{claims_url_v2}/api/v3/claims/submit", body, headers)
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
      if production_environment?
        {
          'Ocp-Apim-Subscription-Key-E' => e_subscription_key,
          'Ocp-Apim-Subscription-Key-S' => s_subscription_key
        }
      else
        { 'Ocp-Apim-Subscription-Key' => subscription_key }
      end
    end

    private

    ##
    # Loads required data from Redis with error handling.
    # Provides clear error messages for Redis failures or missing data.
    #
    def load_redis_data
      @icn = @redis_client.icn(uuid: @check_in_uuid)
      @station_number = @redis_client.station_number(uuid: @uuid)
    rescue Redis::BaseError
      raise ArgumentError,
            "Failed to load data from Redis for check_in_session UUID #{@check_in_uuid} and " \
            "station number #{@station_number}"
    end

    def validate_required_arguments
      raise ArgumentError, 'UUID cannot be blank' if @uuid.blank?
      raise ArgumentError, 'Check-in UUID cannot be blank' if @check_in_uuid.blank?
      raise ArgumentError, 'appointment date time cannot be blank' if @appointment_date_time.blank?
    end

    def validate_redis_data
      missing_args = []
      missing_args << 'ICN' if @icn.blank?
      missing_args << 'station number' if @station_number.blank?

      raise ArgumentError, "Missing required arguments: #{missing_args.join(', ')}" unless missing_args.empty?
    end

    def production_environment?
      Settings.vsp_environment == 'production'
    end

    def headers
      headers = {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{@current_veis_token}",
        'X-BTSSS-Token' => @current_btsss_token,
        'X-Correlation-ID' => @correlation_id
      }

      headers.merge!(subscription_key_headers)
    end

    ##
    # Wraps external API calls to ensure proper authentication.
    # Handles token refresh on unauthorized responses with retry limit.
    #
    # @yield Block containing the API call to make
    # @return [Faraday::Response] API response
    #
    def with_auth
      @auth_retry_attempted = false
      ensure_tokens!
      yield
    rescue Common::Exceptions::BackendServiceException => e
      if e.original_status == 401 && !@auth_retry_attempted
        @auth_retry_attempted = true
        refresh_tokens!
        yield # Retry once with fresh tokens
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

      cached_veis = @redis_client.token
      if cached_veis
        @current_veis_token = cached_veis
        fetch_btsss_token! if @current_btsss_token.nil?
        return
      end

      fetch_tokens!
    end

    ##
    # Fetches fresh tokens.
    # Updates internal token state and stores VEIS token in Redis.
    #
    def fetch_tokens!
      veis_response = veis_token_request

      raise_backend_error('VEIS response missing access_token') unless veis_response.body&.[]('access_token')

      @current_veis_token = veis_response.body['access_token']
      fetch_btsss_token!
      @redis_client.save_token(token: @current_veis_token)
    end

    ##
    # Fetches BTSSS token using current VEIS token.
    # BTSSS token is user-specific and stored only in instance.
    #
    def fetch_btsss_token!
      btsss_response = system_access_token_request(
        client_number: nil,
        veis_access_token: @current_veis_token,
        icn: @icn
      )

      unless btsss_response.body&.dig('data', 'accessToken')
        raise_backend_error('BTSSS response missing accessToken in data')
      end

      @current_btsss_token = btsss_response.body['data']['accessToken']
    end

    ##
    # Refreshes tokens.
    # Clears current tokens and Redis cache, then fetches new ones.
    #
    def refresh_tokens!
      @current_veis_token = nil
      @current_btsss_token = nil
      @redis_client.save_token(token: nil)
      fetch_tokens!
    end

    def raise_backend_error(detail)
      raise Common::Exceptions::BackendServiceException.new('CheckIn travel claim submission error', { detail: })
    end

    ##
    # Override perform method to handle PATCH requests
    # The base configuration doesn't support PATCH, so we handle it specially
    #
    def perform(method, path, params, headers = nil, options = nil)
      if method == :patch
        request(:patch, path, params || {}, headers || {}, options || {})
      else
        super
      end
    end
  end
end
