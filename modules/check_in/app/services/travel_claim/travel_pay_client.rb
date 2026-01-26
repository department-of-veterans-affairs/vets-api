# frozen_string_literal: true

require 'forwardable'
require 'digest'

module TravelClaim
  ##
  # Client for interacting with the Travel Pay API (BTSSS).
  #
  # Supports two initialization patterns:
  # - Provide check_in_uuid to load ICN/station_number from Redis
  # - Provide ICN and station_number directly
  #
  class TravelPayClient < Common::Client::Base
    extend Forwardable
    include Common::Client::Concerns::Monitoring

    EXPENSE_DESCRIPTION = 'mileage'
    TRIP_TYPE           = 'RoundTrip'
    GRANT_TYPE          = 'client_credentials'
    CLIENT_TYPE         = '1'
    CLAIM_NAME          = 'Travel Reimbursement'
    CLAIMANT_TYPE       = 'Veteran'
    STATSD_KEY_PREFIX   = 'api.check_in.travel_claim'
    API_EXCEPTIONS      = [
      Common::Exceptions::BackendServiceException,
      Common::Client::Errors::ClientError,
      Common::Exceptions::GatewayTimeout
    ].freeze

    attr_reader :settings

    def_delegators :settings, :auth_url, :tenant_id, :travel_pay_client_id, :travel_pay_client_secret,
                   :travel_pay_client_secret_oh, :claims_url_v2, :claims_base_path_v2, :subscription_key,
                   :e_subscription_key, :s_subscription_key, :client_number, :travel_pay_resource,
                   :client_secret

    ##
    # @param appointment_date_time [String] ISO 8601 appointment date/time
    # @param check_in_uuid [String, nil] UUID to load ICN/station_number from Redis
    # @param icn [String, nil] Patient ICN (loaded from Redis if not provided)
    # @param station_number [String, nil] Facility station number (loaded from Redis if not provided)
    # @param facility_type [String, nil] Facility type ('oh' for Oracle Health, or other values)
    #
    def initialize(appointment_date_time:, check_in_uuid: nil, icn: nil, station_number: nil, facility_type: nil)
      @appointment_date_time = appointment_date_time
      @check_in_uuid = check_in_uuid
      @icn = icn
      @station_number = station_number
      @facility_type = facility_type
      @settings = Settings.check_in.travel_reimbursement_api_v2
      @correlation_id = SecureRandom.uuid

      validate_arguments
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

    # ------------ Auth requests ------------

    ##
    # Gets a VEIS access token for API authentication.
    #
    # @return [Faraday::Response] HTTP response containing access token
    #
    def veis_token_request
      with_monitoring do
        body = URI.encode_www_form({
                                     client_id: travel_pay_client_id,
                                     client_secret:,
                                     client_type: CLIENT_TYPE,
                                     grant_type: GRANT_TYPE,
                                     resource: travel_pay_resource
                                   })

        headers = { 'Content-Type' => 'application/x-www-form-urlencoded' }
        perform(:post, "#{tenant_id}/oauth2/token", body, headers, { server_url: auth_url })
      end
    rescue *API_EXCEPTIONS => e
      log_external_api_error(endpoint: 'VEIS', operation: 'veis_token_request', error: e)
      enrich_and_reraise_if_needed(e)
    end

    ##
    # Gets a system access token for API authentication.
    #
    # @param client_number [String] Client number for BTSSS API calls
    # @param veis_access_token [String] VEIS access token
    # @param icn [String] Patient ICN
    # @return [Faraday::Response] HTTP response containing access token
    #
    def system_access_token_request(veis_access_token:, icn:)
      with_monitoring do
        body = { secret: btsss_client_secret, icn: }
        headers = {
          'Content-Type' => 'application/json',
          'X-Correlation-ID' => @correlation_id,
          'BTSSS-API-Client-Number' => client_number.to_s,
          'Authorization' => "Bearer #{veis_access_token}"
        }.merge(subscription_key_headers)
        perform(:post, 'api/v4/auth/system-access-token', body, headers)
      end
    rescue *API_EXCEPTIONS => e
      log_external_api_error(endpoint: 'BTSSS', operation: 'system_access_token_request', error: e)
      enrich_and_reraise_if_needed(e)
    end

    ##
    # Sends a request to find or create an appointment.
    #
    # @return [Faraday::Response] HTTP response containing appointment data
    #
    def send_appointment_request
      with_auth do
        with_monitoring do
          perform(:post, 'api/v3/appointments/find-or-add',
                  { appointmentDateTime: @appointment_date_time, facilityStationNumber: @station_number }, headers)
        end
      end
    rescue *API_EXCEPTIONS => e
      log_external_api_error(endpoint: 'BTSSS', operation: 'find_or_add_appointment', error: e)
      enrich_and_reraise_if_needed(e)
    end

    # Sends a request to create a new claim.
    #
    # @param appointment_id [String] Appointment ID
    # @return [Faraday::Response] HTTP response containing claim data
    #
    def send_claim_request(appointment_id:)
      with_auth do
        with_monitoring do
          perform(:post, 'api/v3/claims',
                  { appointmentId: appointment_id, claimName: CLAIM_NAME, claimantType: CLAIMANT_TYPE }, headers)
        end
      end
    rescue *API_EXCEPTIONS => e
      log_external_api_error(endpoint: 'BTSSS', operation: 'create_claim', error: e)
      enrich_and_reraise_if_needed(e)
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
        with_monitoring do
          perform(:post, 'api/v3/expenses/mileage',
                  { claimId: claim_id, dateIncurred: date_incurred, description: EXPENSE_DESCRIPTION,
                    tripType: TRIP_TYPE }, headers)
        end
      end
    rescue *API_EXCEPTIONS => e
      log_external_api_error(endpoint: 'BTSSS', operation: 'add_mileage_expense', error: e)
      enrich_and_reraise_if_needed(e)
    end

    ##
    # Sends a request to get a claim by ID.
    #
    # @param claim_id [String] Claim ID
    # @return [Faraday::Response] HTTP response containing claim data
    #
    def send_get_claim_request(claim_id:)
      with_auth do
        with_monitoring { perform(:get, "api/v3/claims/#{claim_id}", nil, headers) }
      end
    rescue *API_EXCEPTIONS => e
      log_external_api_error(endpoint: 'BTSSS', operation: 'get_claim', error: e)
      enrich_and_reraise_if_needed(e)
    end

    ##
    # Sends a request to submit a claim for processing.
    #
    # @param claim_id [String] Claim ID
    # @return [Faraday::Response] HTTP response containing submission data
    #
    def send_claim_submission_request(claim_id:)
      with_auth do
        with_monitoring { perform(:patch, "api/v3/claims/#{claim_id}/submit", nil, headers) }
      end
    rescue *API_EXCEPTIONS => e
      log_external_api_error(endpoint: 'BTSSS', operation: 'submit_claim', error: e)
      enrich_and_reraise_if_needed(e)
    end

    # ------------ Keys / headers ------------

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

    ##
    # Selects the appropriate BTSSS client secret based on facility type.
    # Oracle Health facilities use a separate secret from other facilities.
    #
    # @return [String] The appropriate client secret for BTSSS authentication
    #
    def btsss_client_secret
      @facility_type&.downcase == 'oh' ? travel_pay_client_secret_oh : travel_pay_client_secret
    end

    ##
    # Ensures valid tokens are available.
    # Fetches tokens from Redis cache or fetches new ones if needed.
    #
    def headers
      if @current_veis_token.blank? || @current_btsss_token.blank?
        log_with_context('TravelPayClient building headers without tokens')
        missing = [('VEIS token' if @current_veis_token.blank?),
                   ('BTSSS token' if @current_btsss_token.blank?)].compact
        raise TravelClaim::Errors::InvalidArgument, "Missing auth token(s) for request headers: #{missing.join(', ')}"
      end
      {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{@current_veis_token}",
        'BTSSS-Access-Token' => @current_btsss_token,
        'X-Correlation-ID' => @correlation_id
      }.merge(subscription_key_headers)
    end

    # ------------ Token lifecycle ------------

    def ensure_tokens!
      veis_token!
      btsss_token!
    end

    ##
    # Lazily initializes and returns the Redis client for loading identity data and caching tokens.
    #
    def redis_client
      @redis_client ||= TravelClaim::RedisClient.build
    end

    private

    # ------------ Identity prerequisites ------------

    ##
    # Loads required identity data from Redis with error handling.
    #
    # Only loads data that hasn't been provided directly (uses ||= for each field).
    # Redis errors should be handled by the calling method.
    #
    def load_redis_data
      @icn ||= redis_client.icn(uuid: @check_in_uuid)
      @station_number ||= redis_client.station_number(uuid: @check_in_uuid)
    end

    ##
    # Validates that all required arguments are present, loading missing data from Redis if possible.
    #
    # Validation flow:
    # 1. If ICN or station_number is missing and check_in_uuid is provided, loads from Redis
    # 2. Validates all required fields are present after loading
    # 3. Reports all missing arguments at once (no early exits)
    #
    # @raise [TravelClaim::Errors::InvalidArgument] if any required arguments are missing
    #
    def validate_arguments
      redis_failed = false
      if (@icn.blank? || @station_number.blank?) && @check_in_uuid.present?
        begin
          load_redis_data
        rescue Redis::BaseError
          log_redis_error('load_user_data')
          redis_failed = true
        end
      end

      missing = [('appointment date time' if @appointment_date_time.blank?),
                 ('ICN' if @icn.blank?),
                 ('station number' if @station_number.blank?),
                 ('check-in UUID' if (@icn.blank? || @station_number.blank?) && @check_in_uuid.blank?)].compact
      return if missing.empty?

      missing << 'data from Redis (check-in UUID provided but Redis unavailable)' if redis_failed
      log_initialization_error(missing)
      raise TravelClaim::Errors::InvalidArgument, "Missing required arguments: #{missing.join(', ')}"
    end

    def btsss_token!
      return @current_btsss_token if @current_btsss_token.present?

      veis_token! if @current_veis_token.blank?

      resp = system_access_token_request(veis_access_token: @current_veis_token, icn: @icn)
      token = resp.body.dig('data', 'accessToken')
      if token.blank?
        raise Common::Exceptions::BackendServiceException.new('VA900', { detail: 'BTSSS auth missing accessToken' },
                                                              502)
      end
      @current_btsss_token = token
    end

    def veis_token!
      return @current_veis_token if @current_veis_token.present?

      @current_veis_token = Rails.cache.fetch(
        'token',
        namespace: 'check-in-btsss-cache-v1',
        expires_in: 54.minutes,
        race_condition_ttl: 5.minutes
      ) do
        log_with_context('Minting new VEIS token')
        StatsD.increment('api.check_in.travel_claim.veis_token.mint')
        mint_veis_token
      end
    end

    def mint_veis_token
      resp = veis_token_request
      token = resp.body['access_token']
      if token.blank?
        raise Common::Exceptions::BackendServiceException.new('VA900', { detail: 'VEIS auth missing access_token' },
                                                              502)
      end
      token
    end

    # ------------ Auth wrapper ------------

    ##
    # Wraps external API calls to ensure proper authentication.
    # Retries once on 401 by clearing instance tokens and re-fetching from cache.
    # With race_condition_ttl, multiple processes won't stampede the cache.
    #
    # @yield Block containing the API call to make
    # @return [Faraday::Response] API response
    #
    def with_auth
      @auth_retry_attempted = false
      ensure_tokens!
      assert_auth_context!
      yield
    rescue Common::Exceptions::BackendServiceException => e
      if e.original_status == 401 && !@auth_retry_attempted
        @auth_retry_attempted = true
        log_with_context('TravelPayClient 401 error - retrying authentication')
        @current_veis_token = nil
        @current_btsss_token = nil
        ensure_tokens!
        assert_auth_context!
        yield
      else
        raise
      end
    end

    def assert_auth_context!
      return if @current_veis_token.present? && @current_btsss_token.present? && @icn.present?

      log_with_context('TravelPayClient auth context incomplete',
                       icn_present: @icn.present?)
      missing = [('VEIS token' if @current_veis_token.blank?),
                 ('BTSSS token' if @current_btsss_token.blank?),
                 ('ICN' if @icn.blank?)].compact
      raise TravelClaim::Errors::InvalidArgument, "Auth context missing: #{missing.join(', ')}"
    end

    # ------------ Env & perform ------------

    def production_environment?
      Settings.vsp_environment == 'production'
    end

    ##
    # Override perform method to handle PATCH requests and optional server_url
    # The base configuration doesn't support PATCH, so we handle it specially
    # Also allows overriding the server URL for authentication requests via options
    #
    def perform(method, path, params, headers = nil, options = nil)
      server_url = options&.delete(:server_url)

      if method == :patch
        request(:patch, path, params || {}, headers || {}, options || {})
      elsif server_url
        custom_connection = config.connection(server_url:)
        custom_connection.send(method.to_sym, path, params || {}) do |request|
          request.headers.update(headers || {})
          (options || {}).each { |option, value| request.options.send("#{option}=", value) }
        end.env
      else
        super
      end
    end

    # ------------ Logging helpers (no PHI) ------------

    ##
    # Unified logging method for all external API errors (VEIS/BTSSS).
    # Always logs error occurrence; detailed error messages are gated by flipper flag.
    #
    # @param endpoint [String] 'VEIS' or 'BTSSS'
    # @param operation [String] what step failed (e.g., 'veis_token_request', 'create_claim')
    # @param error [Exception] the exception object (usually BackendServiceException)
    # @param context [Hash] additional context to include in logs
    #
    def log_external_api_error(endpoint:, operation:, error: nil, **context)
      log_data = build_base_log_data(endpoint, operation)
      log_data.merge!(extract_error_details(error)) if error.present?
      log_data.merge!(context)

      Rails.logger.error(log_data)
    end

    def build_base_log_data(endpoint, operation)
      {
        message: "TravelPayClient: #{endpoint} API Error",
        endpoint:,
        operation:,
        correlation_id: @correlation_id,
        check_in_uuid: @check_in_uuid,
        facility_type: @facility_type,
        veis_token_present: @current_veis_token.present?,
        btsss_token_present: @current_btsss_token.present?
      }
    end

    def extract_error_details(error)
      details = { error_class: error.class.name }
      details[:http_status] = extract_actual_status(error)
      details[:error_code] = error.key if error.respond_to?(:key)

      # Only include detailed error messages if flipper flag is enabled
      if Flipper.enabled?(:check_in_experience_travel_claim_log_api_error_details)
        if error.respond_to?(:original_body) && error.original_body.present?
          details[:api_error_message] = extract_and_redact_message(error.original_body)
        end

        if error.respond_to?(:response_values) && error.response_values[:detail].present?
          details[:error_detail] = error.response_values[:detail]
        end
      end

      details
    end

    def log_initialization_error(missing_args)
      log_with_context('TravelPayClient: Initialization failed',
                       missing_arguments: missing_args,
                       redis_data_loaded: @icn.present? && @station_number.present?)
    end

    def log_redis_error(operation)
      log_with_context('TravelPayClient: Redis error',
                       operation:,
                       icn_present: @icn.present?,
                       station_number_present: @station_number.present?)
    end

    def log_with_context(message, **extra_fields)
      return unless Flipper.enabled?(:check_in_experience_travel_claim_logging)

      Rails.logger.error(message, base_log_context.merge(extra_fields))
    end

    def base_log_context
      {
        correlation_id: @correlation_id,
        check_in_uuid: @check_in_uuid,
        facility_type: @facility_type,
        veis_token_present: @current_veis_token.present?,
        btsss_token_present: @current_btsss_token.present?
      }
    end

    def extract_actual_status(error)
      return error.original_status if error.respond_to?(:original_status) && !error.original_status.nil?
      return error.status if error.respond_to?(:status)
      return error.status_code if error.respond_to?(:status_code)

      nil
    end

    def extract_and_redact_message(body)
      return nil unless body

      parsed = body.is_a?(String) ? JSON.parse(body) : body
      message = parsed['message'] || parsed['error'] || parsed['detail']
      return nil unless message.is_a?(String)

      # Use standard DataScrubber to remove PII/PHI (ICN, SSN, etc.)
      Logging::Helper::DataScrubber.scrub(message)
    rescue JSON::ParserError
      nil
    end

    ##
    # Enriches BackendServiceException with BTSSS error message and re-raises.
    # BTSSS returns errors in 'message' field, but middleware only extracts 'detail'.
    # This ensures response_values[:detail] is populated for controller use.
    #
    # @param error [Exception] the error to enrich and re-raise
    #
    def enrich_and_reraise_if_needed(error)
      if error.is_a?(Common::Exceptions::BackendServiceException) &&
         error.response_values[:detail].nil? &&
         error.original_body.present?
        message = extract_message_from_body(error.original_body)
        if message
          raise Common::Exceptions::BackendServiceException.new(
            error.key,
            error.response_values.merge(detail: message),
            error.original_status,
            error.original_body
          )
        end
      end
      raise
    end

    ##
    # Extracts error message from BTSSS response body
    #
    # @param body [String, Hash] the response body
    # @return [String, nil] the error message
    #
    def extract_message_from_body(body)
      return nil unless body

      parsed = body.is_a?(String) ? JSON.parse(body) : body
      parsed['message'] || parsed['detail']
    rescue JSON::ParserError
      nil
    end
  end
end
