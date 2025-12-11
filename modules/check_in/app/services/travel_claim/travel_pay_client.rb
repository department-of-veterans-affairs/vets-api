# frozen_string_literal: true

require 'forwardable'
require 'digest'
require 'logging/helper/data_scrubber'

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
        body = URI.encode_www_form(
          client_id: travel_pay_client_id,
          client_secret:,
          client_type: CLIENT_TYPE,
          grant_type: GRANT_TYPE,
          resource: travel_pay_resource
        )

        headers = { 'Content-Type' => 'application/x-www-form-urlencoded' }
        api_request(:post, "#{tenant_id}/oauth2/token", body, {
                      headers:,
                      options: { server_url: auth_url },
                      endpoint: 'VEIS',
                      is_auth_request: true
                    })
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
      with_monitoring do
        # Log presence booleans only — no PHI/PII
        Rails.logger.info('TravelPayClient BTSSS auth preflight', {
                            correlation_id: @correlation_id,
                            icn_present: icn.present?
                          })

        body = { secret: btsss_client_secret, icn: }
        headers = {
          'Content-Type' => 'application/json',
          'X-Correlation-ID' => @correlation_id,
          'BTSSS-API-Client-Number' => client_number.to_s,
          'Authorization' => "Bearer #{veis_access_token}"
        }.merge(subscription_key_headers)
        api_request(:post, 'api/v4/auth/system-access-token', body, {
                      headers:,
                      endpoint: 'BTSSS',
                      is_auth_request: true
                    })
      end
    end

    ##
    # Sends a request to find or create an appointment.
    #
    # @return [Faraday::Response] HTTP response containing appointment data
    #
    def send_appointment_request
      with_monitoring do
        api_request(:post, 'api/v3/appointments/find-or-add',
                    { appointmentDateTime: @appointment_date_time, facilityStationNumber: @station_number })
      end
    end

    # Sends a request to create a new claim.
    #
    # @param appointment_id [String] Appointment ID
    # @return [Faraday::Response] HTTP response containing claim data
    #
    def send_claim_request(appointment_id:)
      with_monitoring do
        api_request(:post, 'api/v3/claims',
                    { appointmentId: appointment_id, claimName: CLAIM_NAME, claimantType: CLAIMANT_TYPE })
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
      with_monitoring do
        api_request(:post, 'api/v3/expenses/mileage',
                    { claimId: claim_id, dateIncurred: date_incurred, description: EXPENSE_DESCRIPTION,
                      tripType: TRIP_TYPE })
      end
    end

    ##
    # Sends a request to get a claim by ID.
    #
    # @param claim_id [String] Claim ID
    # @return [Faraday::Response] HTTP response containing claim data
    #
    def send_get_claim_request(claim_id:)
      with_monitoring do
        api_request(:get, "api/v3/claims/#{claim_id}", nil)
      end
    end

    ##
    # Sends a request to submit a claim for processing.
    #
    # @param claim_id [String] Claim ID
    # @return [Faraday::Response] HTTP response containing submission data
    #
    def send_claim_submission_request(claim_id:)
      with_monitoring do
        api_request(:patch, "api/v3/claims/#{claim_id}/submit", nil)
      end
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
        log_error('TravelPayClient building headers without tokens')
        missing = build_missing_list('VEIS token' => @current_veis_token.blank?,
                                     'BTSSS token' => @current_btsss_token.blank?)
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
      redis_failed = fetch_identity_from_redis_if_needed

      missing = build_missing_list('appointment date time' => @appointment_date_time.blank?,
                                   'ICN' => @icn.blank?,
                                   'station number' => @station_number.blank?,
                                   'check-in UUID' => (@icn.blank? || @station_number.blank?) && @check_in_uuid.blank?)
      return if missing.empty?

      missing << 'data from Redis (check-in UUID provided but Redis unavailable)' if redis_failed
      log_error('TravelPayClient initialization failed',
                missing_arguments: missing,
                redis_data_loaded: @icn.present? && @station_number.present?)
      raise TravelClaim::Errors::InvalidArgument, "Missing required arguments: #{missing.join(', ')}"
    end

    def ensure_identity_context!
      return if @icn.present? && @station_number.present?

      log_error('TravelPayClient identity context missing',
                icn_present: @icn.present?, station_number_present: @station_number.present?)
      missing = build_missing_list('ICN' => @icn.blank?, 'station number' => @station_number.blank?)
      raise TravelClaim::Errors::InvalidArgument, "Missing required arguments: #{missing.join(', ')}"
    end

    def btsss_token!
      return @current_btsss_token if @current_btsss_token.present?

      veis_token! if @current_veis_token.blank?

      if @icn.blank?
        log_error('TravelPayClient BTSSS token mint aborted (missing ICN)', icn_present: false)
        raise TravelClaim::Errors::InvalidArgument, 'ICN is required to request BTSSS token'
      end

      resp = system_access_token_request(veis_access_token: @current_veis_token, icn: @icn)
      @current_btsss_token = extract_token_from_response(resp, 'data', 'accessToken', 'BTSSS auth missing accessToken')
    end

    def veis_token!
      return @current_veis_token if @current_veis_token.present?

      cached = redis_client.v1_veis_token
      if cached.present?
        @current_veis_token = cached
      else
        @current_veis_token = mint_veis_token
        redis_client.save_v1_veis_token(token: @current_veis_token)
      end

      @current_veis_token
    end

    def mint_veis_token
      resp = veis_token_request
      token = resp.body['access_token']
      if token.blank?
        raise Common::Exceptions::BackendServiceException.new('VA900',
                                                              { detail: 'VEIS auth missing access_token' },
                                                              502)
      end

      token
    end

    def refresh_tokens!
      @current_veis_token  = nil
      @current_btsss_token = nil
      redis_client.save_v1_veis_token(token: nil)
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
    def with_auth(&)
      @auth_retry_attempted = false
      ensure_tokens!
      assert_auth_context!
      yield
    rescue Common::Exceptions::BackendServiceException => e
      return retry_auth(&) if retryable_auth?(e)

      raise
    end

    def assert_auth_context!
      return if @current_veis_token.present? && @current_btsss_token.present? && @icn.present?

      log_error('TravelPayClient auth context incomplete', icn_present: @icn.present?)
      missing = build_missing_list('VEIS token' => @current_veis_token.blank?,
                                   'BTSSS token' => @current_btsss_token.blank?,
                                   'ICN' => @icn.blank?)
      raise TravelClaim::Errors::InvalidArgument, "Auth context missing: #{missing.join(', ')}"
    end

    # ------------ API request wrapper ------------

    def api_request(method, path, params = nil, request_options = {})
      headers = request_options[:headers]
      options = request_options[:options]
      endpoint = request_options[:endpoint] || 'BTSSS'
      is_auth_request = request_options[:is_auth_request] || false

      if is_auth_request
        perform(method, path, params, headers || {}, options)
      else
        with_auth { perform(method, path, params, headers || self.headers, options) }
      end
    rescue *API_EXCEPTIONS => e
      handle_backend_service_exception(e, endpoint:, is_auth_request:)
    rescue => e
      log_error("TravelPayClient #{endpoint || 'API'} unexpected error", error: e)
      raise
    end

    def extract_token_from_response(resp, *path, error_message)
      token = resp.body.dig(*path)
      raise Common::Exceptions::BackendServiceException.new('VA900', { detail: error_message }, 502) if token.blank?

      token
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

    # ------------ Helpers ------------

    def build_missing_list(**checks)
      checks.select { |_name, missing| missing }.keys
    end

    # ------------ Logging helpers (no PHI) ------------
    ##
    # Extracts message from either an error object or response body
    #
    # @param source [Exception, String, Hash, nil] Error object or response body
    # @return [String, nil] Extracted message or nil
    #
    def extract_message(source)
      return nil unless source

      if source.is_a?(Exception)
        # Extract from error object
        if source.respond_to?(:response_values) && source.response_values[:detail]
          return source.response_values[:detail]
        end

        source.message if source.respond_to?(:message)
      else
        # Extract from response body
        parsed = source.is_a?(String) ? JSON.parse(source) : source
        parsed['message'] || parsed['error'] || parsed['detail']
      end
    rescue JSON::ParserError
      nil
    end

    ##
    # Logs an error. If Flipper flag is enabled, extracts and redacts message from error/body.
    #
    def log_error(log_message, **fields)
      error = fields.delete(:error)
      body = fields.delete(:body)

      fields[:status] ||= extract_actual_status(error) if error
      fields[:error_class] ||= error.class.name if error
      fields[:body_present] = body.present? unless fields.key?(:body_present)

      if Flipper.enabled?(:check_in_experience_travel_claim_error_message_logging)
        downstream_message = extract_message(error) || extract_message(body)
        if downstream_message.is_a?(String) && downstream_message.present?
          scrubbed = Logging::Helper::DataScrubber.scrub(downstream_message)
          if fields[:message].present?
            fields[:downstream_message] = scrubbed
          else
            fields[:message] = scrubbed
          end
        end
      elsif fields[:message].blank?
        fields.delete(:message)
      end

      log_data = base_log_context.merge(fields).compact
      Rails.logger.error(log_message, log_data)
    end

    def base_log_context
      {
        correlation_id: @correlation_id,
        check_in_uuid: @check_in_uuid,
        veis_token_present: @current_veis_token.present?,
        btsss_token_present: @current_btsss_token.present?
      }
    end

    def handle_backend_service_exception(error, endpoint: nil, is_auth_request: false) # rubocop:disable Lint/UnusedMethodArgument
      status = extract_actual_status(error)
      body = error.respond_to?(:original_body) ? error.original_body : error.try(:body)

      log_error("TravelPayClient #{endpoint || 'API'} endpoint error", status:, endpoint:, error:, body:)
      return raise existing_claim_exception(error, status, body) if existing_claim?(status, body)

      raise rewrapped_exception(error) if rewrap_backend_exception?(error)

      raise
    end

    def extract_actual_status(error)
      return error.original_status if error.respond_to?(:original_status) && !error.original_status.nil?
      return error.status if error.respond_to?(:status)
      return error.status_code if error.respond_to?(:status_code)

      nil
    end

    def fetch_identity_from_redis_if_needed
      return false unless (@icn.blank? || @station_number.blank?) && @check_in_uuid.present?

      load_redis_data
      false
    rescue Redis::BaseError
      log_error('TravelPayClient Redis error',
                operation: 'load_user_data',
                icn_present: @icn.present?,
                station_number_present: @station_number.present?)
      true
    end

    def retryable_auth?(error)
      error.original_status == 401 && !@auth_retry_attempted
    end

    def retry_auth
      @auth_retry_attempted = true
      log_error('TravelPayClient 401 error - retrying authentication')
      refresh_tokens!
      assert_auth_context!
      yield
    end

    def existing_claim?(status, body)
      return false unless status == 400

      message = extract_message(body)
      message&.include?('already been created')
    end

    def existing_claim_exception(error, status, body)
      detail = 'Validation failed: A claim has already been created for this appointment.'
      log_error('TravelPayClient existing claim error', message: detail)

      Common::Exceptions::BackendServiceException.new(
        error.respond_to?(:key) ? error.key : 'VA900',
        error.respond_to?(:response_values) ? error.response_values.merge(detail:) : { detail: },
        status || 400,
        body
      )
    end

    def rewrap_backend_exception?(error)
      error.is_a?(Common::Exceptions::BackendServiceException) &&
        error.response_values[:detail].nil? &&
        error.original_body.present?
    end

    def rewrapped_exception(error)
      message = extract_message(error.original_body)
      return error unless message

      Common::Exceptions::BackendServiceException.new(
        error.key,
        error.response_values.merge(detail: message),
        error.original_status,
        error.original_body
      )
    end
  end
end
