# frozen_string_literal: true

module TravelClaim
  ##
  # Manages authentication tokens for Travel Claim API operations.
  #
  # Handles token acquisition, caching, refresh, and retry logic for VEIS and BTSSS tokens.
  # Provides a with_auth wrapper that automatically handles 401 (unauthorized) and
  # 409 (contact ID mismatch) errors by refreshing appropriate tokens and retrying.
  #
  # Inherits from V1::BaseClient for circuit breaker protection, error handling,
  # Datadog tracing, and StatsD metrics on external API calls.
  #
  class AuthManager < TravelClaim::V1::BaseClient
    attr_reader :station_number, :facility_type, :correlation_id

    VEIS_CACHE_TTL = 54.minutes
    VEIS_RACE_CONDITION_TTL = 5.minutes

    ##
    # Initializes the AuthManager with patient and facility context.
    #
    # @param icn [String] Patient's ICN (required for BTSSS token)
    # @param station_number [String] Facility station number
    # @param facility_type [String, nil] Facility type ('oh' for Oracle Health)
    # @param correlation_id [String, nil] Correlation ID for request tracing
    #
    def initialize(icn:, station_number:, facility_type: nil, correlation_id: nil)
      @icn = icn
      @station_number = station_number
      @facility_type = facility_type
      @correlation_id = correlation_id || SecureRandom.uuid
      @current_veis_token = nil
      @current_btsss_token = nil
      @auth_retry_attempted = false

      validate_veis_settings!
      validate_subscription_keys!
      super()
    end

    ##
    # Wraps API calls with authentication and automatic retry on auth failures.
    #
    # Handles two types of authentication errors:
    # - 401 Unauthorized: Refreshes both VEIS and BTSSS tokens
    # - 409 Contact ID Mismatch: Refreshes only BTSSS token (VEIS is still valid)
    #
    # @yield Block containing the API call to make
    # @return [Object] Result of the block
    # @raise [Common::Exceptions::BackendServiceException] If retry fails or non-auth error
    #
    def with_auth
      @auth_retry_attempted = false
      ensure_tokens!
      yield
    rescue Common::Exceptions::BackendServiceException => e
      if should_retry_auth?(e)
        handle_auth_retry(e)
        yield
      else
        raise
      end
    end

    ##
    # Returns headers required for authenticated BTSSS API requests.
    #
    # @return [Hash] Headers including Authorization, BTSSS-Access-Token, and subscription keys
    # @raise [TravelClaim::Errors::InvalidArgument] If tokens are not available
    #
    def auth_headers
      validate_tokens_present!

      {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{@current_veis_token}",
        'BTSSS-Access-Token' => @current_btsss_token,
        'X-Correlation-ID' => @correlation_id
      }.merge(subscription_key_headers)
    end

    ##
    # Returns the current VEIS token, fetching if needed.
    #
    # @return [String] VEIS access token
    #
    def veis_token
      fetch_veis_token! if @current_veis_token.blank?
      @current_veis_token
    end

    ##
    # Returns the current BTSSS token, fetching if needed.
    #
    # @return [String] BTSSS access token
    #
    def btsss_token
      fetch_btsss_token! if @current_btsss_token.blank?
      @current_btsss_token
    end

    private

    attr_reader :settings

    def redis_client
      @redis_client ||= TravelClaim::RedisClient.build
    end

    ##
    # Refreshes only the BTSSS token, keeping the VEIS token.
    # Used internally for 409 contact ID mismatch errors.
    #
    def refresh_btsss_token!
      log_auth_event('Refreshing BTSSS token only')
      @current_btsss_token = nil
      fetch_btsss_token!
    end

    ##
    # Refreshes both VEIS and BTSSS tokens.
    # Used internally for 401 unauthorized errors.
    #
    def refresh_all_tokens!
      log_auth_event('Refreshing all tokens')
      @current_veis_token = nil
      @current_btsss_token = nil
      ensure_tokens!
    end

    ##
    # Ensures both tokens are available, fetching as needed.
    #
    def ensure_tokens!
      fetch_veis_token! if @current_veis_token.blank?
      fetch_btsss_token! if @current_btsss_token.blank?
    end

    ##
    # Fetches VEIS token from cache or mints a new one.
    # Delegates to RedisClient which handles caching with race_condition_ttl.
    #
    def fetch_veis_token!
      @current_veis_token = redis_client.fetch_veis_token(
        expires_in: VEIS_CACHE_TTL,
        race_condition_ttl: VEIS_RACE_CONDITION_TTL
      ) do
        log_auth_event('Minting new VEIS token')
        StatsD.increment('api.check_in.travel_claim.veis_token.mint')
        mint_veis_token
      end
    end

    ##
    # Mints a fresh VEIS token via OAuth2 client credentials flow.
    #
    # @return [String] VEIS access token
    # @raise [Common::Exceptions::BackendServiceException] If token request fails
    #
    def mint_veis_token
      body = URI.encode_www_form({
                                   client_id: @veis_client_id,
                                   client_secret: @veis_client_secret,
                                   client_type: '1',
                                   grant_type: 'client_credentials',
                                   resource: @veis_resource
                                 })

      headers = { 'Content-Type' => 'application/x-www-form-urlencoded' }
      response = veis_connection.post("#{@veis_tenant_id}/oauth2/token", body, headers)

      token = response.body['access_token']
      raise_token_error('VEIS', 'access_token') if token.blank?
      token
    end

    ##
    # Fetches a fresh BTSSS system access token for the patient.
    # BTSSS tokens are not cached as they are patient-specific and short-lived.
    #
    def fetch_btsss_token!
      fetch_veis_token! if @current_veis_token.blank?

      log_auth_event('Fetching BTSSS token')
      client_secret = if @facility_type.to_s.strip.downcase == 'oh'
                        @btsss_client_secret_oh
                      else
                        @btsss_client_secret_standard
                      end
      body = { secret: client_secret, icn: @icn }
      headers = {
        'X-Correlation-ID' => @correlation_id,
        'BTSSS-API-Client-Number' => @btsss_client_number,
        'Authorization' => "Bearer #{@current_veis_token}"
      }.merge(subscription_key_headers)

      response = TravelClaim::Configuration.instance.connection.post('api/v4/auth/system-access-token', body, headers)

      token = response.body.dig('data', 'accessToken')
      raise_token_error('BTSSS', 'accessToken') if token.blank?
      @current_btsss_token = token
    end

    ##
    # Determines if the error warrants an authentication retry.
    #
    # @param error [Common::Exceptions::BackendServiceException] the error
    # @return [Boolean] true if retry should be attempted
    #
    def should_retry_auth?(error)
      return false if @auth_retry_attempted

      [401, 409].include?(error.original_status)
    end

    ##
    # Handles the authentication retry by clearing appropriate tokens and re-fetching.
    #
    # @param error [Common::Exceptions::BackendServiceException] the error that triggered retry
    #
    def handle_auth_retry(error)
      @auth_retry_attempted = true
      @current_btsss_token = nil

      if error.original_status == 401
        log_auth_event('401 error - refreshing all tokens')
        @current_veis_token = nil
      elsif error.original_status == 409
        log_auth_event('409 error - refreshing BTSSS token only')
      end

      ensure_tokens!
    end

    ##
    # Validates that both tokens are present.
    #
    # @raise [TravelClaim::Errors::InvalidArgument] if tokens are missing
    #
    def validate_tokens_present!
      return if @current_veis_token.present? && @current_btsss_token.present?

      missing = [('VEIS token' if @current_veis_token.blank?),
                 ('BTSSS token' if @current_btsss_token.blank?)].compact
      raise TravelClaim::Errors::InvalidArgument, "Missing auth tokens: #{missing.join(', ')}"
    end

    ##
    # Raises a standardized error for missing token data.
    #
    # @param token_type [String] 'VEIS' or 'BTSSS'
    # @param field [String] the expected field name
    #
    def raise_token_error(token_type, field)
      raise Common::Exceptions::BackendServiceException.new(
        'VA900',
        { detail: "#{token_type} auth response missing #{field}" },
        502
      )
    end

    ##
    # Creates a Faraday connection for VEIS OAuth requests.
    # Uses form-urlencoded content type, not JSON.
    #
    # @return [Faraday::Connection] configured connection
    #
    def veis_connection
      @veis_connection ||= Faraday.new(url: @veis_auth_url) do |conn|
        conn.response :json
        conn.response :raise_error
        conn.adapter Faraday.default_adapter
      end
    end

    ##
    # Logs authentication events when logging is enabled.
    #
    # @param message [String] the message to log
    #
    def log_auth_event(message)
      return unless Flipper.enabled?(:check_in_experience_travel_claim_logging)

      Rails.logger.info({
                          message: "TravelClaim::AuthManager: #{message}",
                          correlation_id: @correlation_id,
                          facility_type: @facility_type,
                          veis_token_present: @current_veis_token.present?,
                          btsss_token_present: @current_btsss_token.present?
                        })
    end

    ##
    # Validates and loads VEIS and BTSSS authentication settings.
    # Subscription keys are validated by the parent class.
    #
    # @raise [RuntimeError] if required settings are missing
    #
    def validate_veis_settings!
      settings = Settings.check_in.travel_reimbursement_api_v2

      # VEIS token settings
      @veis_client_id = require_setting(settings, :travel_pay_client_id)
      @veis_client_secret = require_setting(settings, :client_secret)
      @veis_resource = require_setting(settings, :travel_pay_resource)
      @veis_tenant_id = require_setting(settings, :tenant_id)
      @veis_auth_url = require_setting(settings, :auth_url)

      # BTSSS token settings
      @btsss_client_secret_oh = require_setting(settings, :travel_pay_client_secret_oh)
      @btsss_client_secret_standard = require_setting(settings, :travel_pay_client_secret)
      @btsss_client_number = require_setting(settings, :client_number)
    end
  end
end
