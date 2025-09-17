# frozen_string_literal: true

require 'forwardable'
require 'digest'

module TravelClaim
  ##
  # Unified client for all Travel Claim API operations.
  # Consolidates functionality from individual clients into a single interface.
  #
  class TravelPayClient < Common::Client::Base
    extend Forwardable
    include Common::Client::Concerns::Monitoring

    EXPENSE_DESCRIPTION = 'mileage'
    TRIP_TYPE = 'RoundTrip'
    GRANT_TYPE = 'client_credentials'
    CLIENT_TYPE = '1'
    CLAIM_NAME = 'Travel Reimbursement'
    CLAIMANT_TYPE = 'Veteran'
    STATSD_KEY_PREFIX = 'api.check_in.travel_claim'

    attr_reader :redis_client, :settings

    # Delegate settings methods directly to the settings object
    def_delegators :settings, :auth_url, :tenant_id, :travel_pay_client_id, :travel_pay_client_secret,
                   :scope, :claims_url_v2, :subscription_key, :e_subscription_key, :s_subscription_key,
                   :client_number, :travel_pay_resource, :client_secret

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

    private

    ##
    # Loads required data from Redis with error handling.
    # Provides clear error messages for Redis failures or missing data.
    #
    def load_redis_data
      @icn = @redis_client.icn(uuid: @check_in_uuid)
      @station_number = @redis_client.station_number(uuid: @uuid)
    rescue Redis::BaseError
      log_redis_error('load_user_data')
      raise ArgumentError,
            "Failed to load data from Redis for check_in_session UUID #{@check_in_uuid} " \
            "and station number #{@station_number}"
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

      unless missing_args.empty?
        log_initialization_error(missing_args)
        raise ArgumentError, "Missing required arguments: #{missing_args.join(', ')}"
      end
    end

    def production_environment?
      Settings.vsp_environment == 'production'
    end

    def headers
      headers = {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{@current_veis_token}",
        'BTSSS-Access-Token' => @current_btsss_token,
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
        log_auth_retry
        refresh_tokens!
        yield # Retry once with fresh tokens
      elsif e.original_status == 401 && @auth_retry_attempted
        log_auth_error(e.class.name, e.respond_to?(:original_status) ? e.original_status : nil)
        raise
      else
        raise e
      end
    end

    ##
    # Fetches fresh tokens.
    # Updates internal token state and stores VEIS token in Redis.
    #
    def fetch_tokens!
      veis_response = veis_token_request
      @current_veis_token = veis_response.body['access_token']
      fetch_btsss_token!
      @redis_client.save_token(token: @current_veis_token)
    rescue Common::Exceptions::BackendServiceException => e
      log_token_error('VEIS', 'token_request_failed')
      raise e
    end

    ##
    # Fetches BTSSS token using current VEIS token.
    # BTSSS token is user-specific and stored only in instance.
    #
    def fetch_btsss_token!
      btsss_response = system_access_token_request(
        veis_access_token: @current_veis_token,
        icn: @icn
      )
      @current_btsss_token = btsss_response.body['data']['accessToken']
    rescue Common::Exceptions::BackendServiceException => e
      log_token_error('BTSSS', 'token_request_failed')
      raise e
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

    ##
    # Logging helper methods for errors and state information only
    #

    def log_initialization_error(missing_args)
      Rails.logger.error('TravelPayClient initialization failed', {
                           correlation_id: @correlation_id,
                           uuid_hash: @uuid,
                           missing_arguments: missing_args,
                           redis_data_loaded: @icn.present? && @station_number.present?
                         })
    end

    def log_redis_error(operation)
      Rails.logger.error('TravelPayClient Redis error', {
                           correlation_id: @correlation_id,
                           uuid_hash: @uuid,
                           operation:,
                           icn_present: @icn.present?,
                           station_number_present: @station_number.present?
                         })
    end

    def log_auth_retry
      Rails.logger.error('TravelPayClient 401 error - retrying authentication', {
                           correlation_id: @correlation_id,
                           uuid_hash: @uuid,
                           veis_token_present: @current_veis_token.present?,
                           btsss_token_present: @current_btsss_token.present?
                         })
    end

    def log_auth_error(error_type, status_code)
      Rails.logger.error('TravelPayClient authentication failed', {
                           correlation_id: @correlation_id,
                           uuid_hash: @uuid,
                           error_type:,
                           status_code:,
                           veis_token_present: @current_veis_token.present?,
                           btsss_token_present: @current_btsss_token.present?
                         })
    end

    def log_token_error(service, issue)
      Rails.logger.error('TravelPayClient token error', {
                           correlation_id: @correlation_id,
                           uuid_hash: @uuid,
                           service:,
                           issue:,
                           veis_token_present: @current_veis_token.present?,
                           btsss_token_present: @current_btsss_token.present?
                         })
    end

    def log_existing_claim_error
      Rails.logger.error('TravelPayClient existing claim error', {
                           correlation_id: @correlation_id,
                           uuid_hash: @uuid,
                           message: 'Validation failed: A claim has already been created for this appointment.'
                         })
    end

    def extract_message_from_response(body)
      return nil unless body

      parsed = if body.is_a?(String)
                 JSON.parse(body)
               else
                 body
               end

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
