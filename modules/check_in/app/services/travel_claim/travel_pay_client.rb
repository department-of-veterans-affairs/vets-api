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

    attr_reader :settings

    def_delegators :settings, :auth_url, :tenant_id, :travel_pay_client_id, :travel_pay_client_secret,
                   :scope, :claims_url_v2, :subscription_key, :e_subscription_key, :s_subscription_key,
                   :client_number, :travel_pay_resource, :client_secret

    ##
    # @param appointment_date_time [String] ISO 8601 appointment date/time
    # @param check_in_uuid [String, nil] UUID to load ICN/station_number from Redis
    # @param icn [String, nil] Patient ICN (loaded from Redis if not provided)
    # @param station_number [String, nil] Facility station number (loaded from Redis if not provided)
    #
    def initialize(appointment_date_time:, check_in_uuid: nil, icn: nil, station_number: nil)
      @appointment_date_time = appointment_date_time
      @check_in_uuid = check_in_uuid
      @icn = icn
      @station_number = station_number
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
                                     scope:,
                                     grant_type: GRANT_TYPE,
                                     resource: travel_pay_resource
                                   })

        headers = { 'Content-Type' => 'application/x-www-form-urlencoded' }
        perform(:post, "#{tenant_id}/oauth2/token", body, headers, { server_url: auth_url })
      end
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
      # Log presence booleans only — no PHI/PII
      Rails.logger.info('TravelPayClient BTSSS auth preflight', {
                          correlation_id: @correlation_id,
                          icn_present: icn.present?
                        })

      with_monitoring do
        body = { secret: travel_pay_client_secret, icn: }

        headers = {
          'Content-Type' => 'application/json',
          'X-Correlation-ID' => @correlation_id,
          'BTSSS-API-Client-Number' => client_number.to_s,
          'Authorization' => "Bearer #{veis_access_token}"
        }.merge(subscription_key_headers)

        perform(:post, 'api/v4/auth/system-access-token', body, headers)
      end
    end

    ##
    # Sends a request to find or create an appointment.
    #
    # @return [Faraday::Response] HTTP response containing appointment data
    #
    def send_appointment_request
      with_auth do
        with_monitoring do
          body = {
            appointmentDateTime: @appointment_date_time,
            facilityStationNumber: @station_number
          }

          perform(:post, 'api/v3/appointments/find-or-add', body, headers)
        end
      end
    rescue Common::Exceptions::BackendServiceException => e
      handle_backend_service_exception(e)
    end

    # Sends a request to create a new claim.
    #
    # @param appointment_id [String] Appointment ID
    # @return [Faraday::Response] HTTP response containing claim data
    #
    def send_claim_request(appointment_id:)
      with_auth do
        with_monitoring do
          body = {
            appointmentId: appointment_id,
            claimName: CLAIM_NAME,
            claimantType: CLAIMANT_TYPE
          }

          perform(:post, 'api/v3/claims', body, headers)
        end
      end
    rescue Common::Exceptions::BackendServiceException => e
      handle_backend_service_exception(e)
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
          body = {
            claimId: claim_id,
            dateIncurred: date_incurred,
            description: EXPENSE_DESCRIPTION,
            tripType: TRIP_TYPE
          }

          perform(:post, 'api/v3/expenses/mileage', body, headers)
        end
      end
    rescue Common::Exceptions::BackendServiceException => e
      handle_backend_service_exception(e)
    end

    ##
    # Sends a request to get a claim by ID.
    #
    # @param claim_id [String] Claim ID
    # @return [Faraday::Response] HTTP response containing claim data
    #
    def send_get_claim_request(claim_id:)
      with_auth do
        with_monitoring do
          perform(:get, "api/v3/claims/#{claim_id}", nil, headers)
        end
      end
    rescue Common::Exceptions::BackendServiceException => e
      handle_backend_service_exception(e)
    end

    ##
    # Sends a request to submit a claim for processing.
    #
    # @param claim_id [String] Claim ID
    # @return [Faraday::Response] HTTP response containing submission data
    #
    def send_claim_submission_request(claim_id:)
      with_auth do
        with_monitoring do
          perform(:patch, "api/v3/claims/#{claim_id}/submit", nil, headers)
        end
      end
    rescue Common::Exceptions::BackendServiceException => e
      handle_backend_service_exception(e)
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
    # Ensures valid tokens are available.
    # Fetches tokens from Redis cache or fetches new ones if needed.
    #
    def headers
      if @current_veis_token.blank? || @current_btsss_token.blank?
        Rails.logger.error('TravelPayClient building headers without tokens', {
                             correlation_id: @correlation_id,
                             veis_token_present: @current_veis_token.present?,
                             btsss_token_present: @current_btsss_token.present?
                           })
        missing_tokens = []
        missing_tokens << 'VEIS token' if @current_veis_token.blank?
        missing_tokens << 'BTSSS token' if @current_btsss_token.blank?
        raise TravelClaim::Errors::InvalidArgument,
              "Missing auth token(s) for request headers: #{missing_tokens.join(', ')}"
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
      ensure_identity_context!
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
      redis_attempted = false
      redis_failed = false

      if (@icn.blank? || @station_number.blank?) && @check_in_uuid.present?
        redis_attempted = true
        begin
          load_redis_data
        rescue Redis::BaseError
          log_redis_error('load_user_data')
          redis_failed = true
        end
      end

      missing = []
      missing << 'appointment date time' if @appointment_date_time.blank?
      missing << 'ICN' if @icn.blank?
      missing << 'station number' if @station_number.blank?
      missing << 'check-in UUID' if (@icn.blank? || @station_number.blank?) && @check_in_uuid.blank?

      return if missing.empty?

      missing << 'data from Redis (check-in UUID provided but Redis unavailable)' if redis_attempted && redis_failed

      log_initialization_error(missing)
      raise TravelClaim::Errors::InvalidArgument, "Missing required arguments: #{missing.join(', ')}"
    end

    def ensure_identity_context!
      icn_ok = @icn.present?
      stn_ok = @station_number.present?

      unless icn_ok && stn_ok
        Rails.logger.error('TravelPayClient identity context missing', {
                             correlation_id: @correlation_id,
                             icn_present: icn_ok,
                             station_number_present: stn_ok
                           })
        missing = []
        missing << 'ICN' unless icn_ok
        missing << 'station number' unless stn_ok
        raise TravelClaim::Errors::InvalidArgument, "Missing required arguments: #{missing.join(', ')}"
      end
    end

    def btsss_token!
      return @current_btsss_token if @current_btsss_token.present?

      veis_token! if @current_veis_token.blank?

      if @icn.blank?
        Rails.logger.error('TravelPayClient BTSSS token mint aborted (missing ICN)',
                           correlation_id: @correlation_id, icn_present: false)
        raise TravelClaim::Errors::InvalidArgument, 'ICN is required to request BTSSS token'
      end

      Rails.logger.debug('TravelPayClient BTSSS auth preflight',
                         correlation_id: @correlation_id, icn_present: true)

      resp  = system_access_token_request(veis_access_token: @current_veis_token, icn: @icn)
      token = resp.body.dig('data', 'accessToken')
      if token.blank?
        Rails.logger.error('TravelPayClient BTSSS token response missing accessToken',
                           correlation_id: @correlation_id)
        raise Common::Exceptions::BackendServiceException.new('VA900',
                                                              { detail: 'BTSSS auth missing accessToken' }, 502)
      end

      @current_btsss_token = token
    end

    def veis_token!
      return @current_veis_token if @current_veis_token.present?

      cached = redis_client.token
      if cached.present?
        @current_veis_token = cached
        Rails.logger.debug('TravelPayClient VEIS token from cache', correlation_id: @correlation_id)
      else
        @current_veis_token = mint_veis_token
        redis_client.save_token(token: @current_veis_token)
      end

      @current_veis_token
    end

    def mint_veis_token
      resp  = veis_token_request
      token = resp.body['access_token']
      if token.blank?
        Rails.logger.error('TravelPayClient VEIS token response missing access_token', correlation_id: @correlation_id)
        raise Common::Exceptions::BackendServiceException.new('VA900', { detail: 'VEIS auth missing access_token' },
                                                              502)
      end
      token
    rescue Common::Exceptions::BackendServiceException
      log_token_error('VEIS', 'token_request_failed')
      raise
    end

    def refresh_tokens!
      @current_veis_token  = nil
      @current_btsss_token = nil
      redis_client.save_token(token: nil)
      ensure_tokens!
    end

    # ------------ Auth wrapper ------------

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
      assert_auth_context!
      yield
    rescue Common::Exceptions::BackendServiceException => e
      if e.original_status == 401 && !@auth_retry_attempted
        @auth_retry_attempted = true
        log_auth_retry
        refresh_tokens!
        assert_auth_context!
        yield
      elsif e.original_status == 401 && @auth_retry_attempted
        log_auth_error(e.class.name, e.respond_to?(:original_status) ? e.original_status : nil)
        raise
      else
        raise
      end
    end

    def assert_auth_context!
      veis_ok  = @current_veis_token.present?
      btsss_ok = @current_btsss_token.present?
      icn_ok   = @icn.present?

      return if veis_ok && btsss_ok && icn_ok

      Rails.logger.error('TravelPayClient auth context incomplete', {
                           correlation_id: @correlation_id,
                           veis_token_present: veis_ok,
                           btsss_token_present: btsss_ok,
                           icn_present: icn_ok
                         })
      missing = []
      missing << 'VEIS token'  unless veis_ok
      missing << 'BTSSS token' unless btsss_ok
      missing << 'ICN'         unless icn_ok
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

    def log_initialization_error(missing_args)
      Rails.logger.error('TravelPayClient initialization failed', {
                           correlation_id: @correlation_id,
                           check_in_uuid: @check_in_uuid,
                           missing_arguments: missing_args,
                           redis_data_loaded: @icn.present? && @station_number.present?
                         })
    end

    def log_redis_error(operation)
      Rails.logger.error('TravelPayClient Redis error', {
                           correlation_id: @correlation_id,
                           check_in_uuid: @check_in_uuid,
                           operation:,
                           icn_present: @icn.present?,
                           station_number_present: @station_number.present?
                         })
    end

    def log_auth_retry
      Rails.logger.error('TravelPayClient 401 error - retrying authentication', {
                           correlation_id: @correlation_id,
                           check_in_uuid: @check_in_uuid,
                           veis_token_present: @current_veis_token.present?,
                           btsss_token_present: @current_btsss_token.present?
                         })
    end

    def log_auth_error(error_type, status_code)
      Rails.logger.error('TravelPayClient authentication failed', {
                           correlation_id: @correlation_id,
                           check_in_uuid: @check_in_uuid,
                           error_type:,
                           status_code:,
                           veis_token_present: @current_veis_token.present?,
                           btsss_token_present: @current_btsss_token.present?
                         })
    end

    def log_token_error(service, issue)
      Rails.logger.error('TravelPayClient token error', {
                           correlation_id: @correlation_id,
                           check_in_uuid: @check_in_uuid,
                           service:,
                           issue:,
                           veis_token_present: @current_veis_token.present?,
                           btsss_token_present: @current_btsss_token.present?
                         })
    end

    def log_existing_claim_error
      Rails.logger.error('TravelPayClient existing claim error', {
                           correlation_id: @correlation_id,
                           check_in_uuid: @check_in_uuid,
                           message: 'Validation failed: A claim has already been created for this appointment.'
                         })
    end

    def extract_message_from_response(body)
      return nil unless body

      parsed = body.is_a?(String) ? JSON.parse(body) : body
      parsed['message']
    rescue JSON::ParserError
      nil
    end

    def handle_backend_service_exception(error)
      log_api_error(error.original_status, error.original_body)
      # Extract message from original body if detail is nil
      if error.response_values[:detail].nil? && error.original_body
        message = extract_message_from_response(error.original_body)
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

    def log_api_error(status, body)
      return unless status

      # Only log specific known error types to avoid exposing PHI
      # Skip 401 errors as they're already logged in with_auth method
      if status == 400
        parsed_message = extract_message_from_response(body)
        if parsed_message&.include?('already been created')
          log_existing_claim_error
        else
          Rails.logger.error('TravelPayClient API error', {
                               correlation_id: @correlation_id,
                               status:,
                               error_type: 'bad_request'
                             })
        end
      elsif status != 401
        Rails.logger.error('TravelPayClient API error', {
                             correlation_id: @correlation_id,
                             status:
                           })
      end
    end
  end
end
