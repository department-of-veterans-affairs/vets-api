# frozen_string_literal: true

module TravelClaim
  ##
  # Client for interacting with the Travel Pay API (BTSSS).
  #
  # Handles HTTP operations for travel claim submission. This client builds its own
  # headers using tokens provided as parameters. Authentication token lifecycle
  # is managed separately by AuthManager and orchestrated by the service.
  #
  class TravelPayClient < Common::Client::Base
    include Common::Client::Concerns::Monitoring

    EXPENSE_DESCRIPTION = 'mileage'
    TRIP_TYPE           = 'RoundTrip'
    CLAIM_NAME          = 'Travel Reimbursement'
    CLAIMANT_TYPE       = 'Veteran'
    STATSD_KEY_PREFIX   = 'api.check_in.travel_claim'
    API_EXCEPTIONS      = [
      Common::Exceptions::BackendServiceException,
      Common::Client::Errors::ClientError,
      Common::Exceptions::GatewayTimeout
    ].freeze

    ##
    # @param appointment_date_time [String] ISO 8601 appointment date/time (required)
    # @param station_number [String] Facility station number (required)
    # @param check_in_uuid [String, nil] UUID for logging context
    # @param facility_type [String, nil] Facility type for logging context
    # @param correlation_id [String, nil] Correlation ID for request tracing
    #
    def initialize(appointment_date_time:, station_number:, check_in_uuid: nil, facility_type: nil, correlation_id: nil)
      @appointment_date_time = appointment_date_time
      @station_number = station_number
      @check_in_uuid = check_in_uuid
      @facility_type = facility_type
      @correlation_id = correlation_id || SecureRandom.uuid

      validate_required_params
      validate_required_settings!
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

    # ------------ API Operations ------------

    ##
    # Sends a request to find or create an appointment.
    #
    # @param veis_token [String] VEIS bearer token
    # @param btsss_token [String] BTSSS access token
    # @return [Faraday::Response] HTTP response containing appointment data
    #
    def send_appointment_request(veis_token:, btsss_token:)
      with_monitoring do
        perform(:post, 'api/v3/appointments/find-or-add',
                { appointmentDateTime: @appointment_date_time, facilityStationNumber: @station_number },
                build_headers(veis_token:, btsss_token:))
      end
    rescue *API_EXCEPTIONS => e
      log_external_api_error(endpoint: 'BTSSS', operation: 'find_or_add_appointment', error: e)
      enrich_and_reraise_if_needed(e)
    end

    ##
    # Sends a request to create a new claim.
    #
    # @param veis_token [String] VEIS bearer token
    # @param btsss_token [String] BTSSS access token
    # @param appointment_id [String] Appointment ID
    # @return [Faraday::Response] HTTP response containing claim data
    #
    def send_claim_request(veis_token:, btsss_token:, appointment_id:)
      with_monitoring do
        perform(:post, 'api/v3/claims',
                { appointmentId: appointment_id, claimName: CLAIM_NAME, claimantType: CLAIMANT_TYPE },
                build_headers(veis_token:, btsss_token:))
      end
    rescue *API_EXCEPTIONS => e
      log_external_api_error(endpoint: 'BTSSS', operation: 'create_claim', error: e)
      enrich_and_reraise_if_needed(e)
    end

    ##
    # Sends a request to add a mileage expense to a claim.
    #
    # @param veis_token [String] VEIS bearer token
    # @param btsss_token [String] BTSSS access token
    # @param claim_id [String] Claim ID
    # @param date_incurred [String] Date expense was incurred (YYYY-MM-DD)
    # @return [Faraday::Response] HTTP response containing expense data
    #
    def send_mileage_expense_request(veis_token:, btsss_token:, claim_id:, date_incurred:)
      with_monitoring do
        perform(:post, 'api/v3/expenses/mileage',
                { claimId: claim_id, dateIncurred: date_incurred, description: EXPENSE_DESCRIPTION,
                  tripType: TRIP_TYPE },
                build_headers(veis_token:, btsss_token:))
      end
    rescue *API_EXCEPTIONS => e
      log_external_api_error(endpoint: 'BTSSS', operation: 'add_mileage_expense', error: e)
      enrich_and_reraise_if_needed(e)
    end

    ##
    # Sends a request to get a claim by ID.
    #
    # @param veis_token [String] VEIS bearer token
    # @param btsss_token [String] BTSSS access token
    # @param claim_id [String] Claim ID
    # @return [Faraday::Response] HTTP response containing claim data
    #
    def send_get_claim_request(veis_token:, btsss_token:, claim_id:)
      with_monitoring do
        perform(:get, "api/v3/claims/#{claim_id}", nil, build_headers(veis_token:, btsss_token:))
      end
    rescue *API_EXCEPTIONS => e
      log_external_api_error(endpoint: 'BTSSS', operation: 'get_claim', error: e)
      enrich_and_reraise_if_needed(e)
    end

    ##
    # Sends a request to submit a claim for processing.
    #
    # @param veis_token [String] VEIS bearer token
    # @param btsss_token [String] BTSSS access token
    # @param claim_id [String] Claim ID
    # @return [Faraday::Response] HTTP response containing submission data
    #
    def send_claim_submission_request(veis_token:, btsss_token:, claim_id:)
      with_monitoring do
        perform(:patch, "api/v3/claims/#{claim_id}/submit", nil, build_headers(veis_token:, btsss_token:))
      end
    rescue *API_EXCEPTIONS => e
      log_external_api_error(endpoint: 'BTSSS', operation: 'submit_claim', error: e)
      enrich_and_reraise_if_needed(e)
    end

    private

    ##
    # Builds HTTP headers for BTSSS API requests.
    #
    # @param veis_token [String] VEIS bearer token
    # @param btsss_token [String] BTSSS access token
    # @return [Hash] Complete headers for API request
    #
    def build_headers(veis_token:, btsss_token:)
      {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{veis_token}",
        'BTSSS-Access-Token' => btsss_token,
        'X-Correlation-ID' => @correlation_id
      }.merge(subscription_key_headers)
    end

    ##
    # Returns subscription key headers based on environment.
    #
    # @return [Hash] Subscription key headers
    #
    def subscription_key_headers
      if Settings.vsp_environment == 'production'
        {
          'Ocp-Apim-Subscription-Key-E' => @subscription_key_e,
          'Ocp-Apim-Subscription-Key-S' => @subscription_key_s
        }
      else
        { 'Ocp-Apim-Subscription-Key' => @subscription_key }
      end
    end

    ##
    # Validates that required parameters are present.
    #
    # @raise [ArgumentError] if any required parameter is missing
    #
    def validate_required_params
      raise ArgumentError, 'appointment_date_time is required' if @appointment_date_time.blank?
      raise ArgumentError, 'station_number is required' if @station_number.blank?
    end

    ##
    # Validates and stores required settings at initialization.
    # Fails fast if any required subscription keys are missing.
    #
    # @raise [RuntimeError] if required settings are missing
    #
    def validate_required_settings!
      settings = Settings.check_in.travel_reimbursement_api_v2

      if Settings.vsp_environment == 'production'
        @subscription_key_e = require_setting(settings, :e_subscription_key)
        @subscription_key_s = require_setting(settings, :s_subscription_key)
      else
        @subscription_key = require_setting(settings, :subscription_key)
      end
    end

    def require_setting(settings, key)
      settings.public_send(key).to_s.presence || raise("Missing required setting: #{key}")
    end

    ##
    # Override perform method to handle PATCH requests.
    # The base configuration doesn't support PATCH, so we handle it specially.
    #
    def perform(method, path, params, headers = nil, options = nil)
      if method == :patch
        request(:patch, path, params || {}, headers || {}, options || {})
      else
        super
      end
    end

    # ------------ Logging helpers (no PHI) ------------

    ##
    # Unified logging method for all external API errors (BTSSS).
    #
    # @param endpoint [String] 'BTSSS'
    # @param operation [String] what step failed
    # @param error [Exception] the exception object
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
        facility_type: @facility_type
      }
    end

    def extract_error_details(error)
      details = { error_class: error.class.name }
      details[:http_status] = extract_actual_status(error)
      details[:error_code] = error.key if error.respond_to?(:key)

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

      Logging::Helper::DataScrubber.scrub(message)
    rescue JSON::ParserError
      nil
    end

    ##
    # Enriches BackendServiceException with BTSSS error message and re-raises.
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
