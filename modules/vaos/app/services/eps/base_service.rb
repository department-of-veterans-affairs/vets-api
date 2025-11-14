# frozen_string_literal: true

require_relative 'token_authentication'

module Eps
  # Eps::BaseService provides common functionality for making REST API requests
  # to the EPS service.
  class BaseService < VAOS::SessionService
    include Common::Client::Concerns::Monitoring
    include Eps::TokenAuthentication
    include VAOS::CommunityCareConstants

    STATSD_KEY_PREFIX = 'api.eps'
    REDIS_TOKEN_KEY = REDIS_CONFIG[:eps_access_token][:namespace]
    REDIS_TOKEN_TTL = REDIS_CONFIG[:eps_access_token][:each_ttl]

    ##
    # Returns the configuration for the EPS service.
    #
    # @return [Eps::Configuration] An instance of Eps::Configuration loaded from settings.
    def config
      @config ||= Eps::Configuration.instance
    end

    ##
    # Returns the settings for the EPS service.
    #
    # @return [Hash] The settings loaded from the VAOS configuration.
    def settings
      @settings ||= Settings.vaos.eps
    end

    protected

    ##
    # Checks EPS response for error field and raises exception if found.
    # This provides consistent error handling across all EPS service methods.
    #
    # @param response_data [Object] The response data (OpenStruct, Hash, etc.)
    # @param response [Object] The original HTTP response object
    # @param method_name [String] The calling method name for logging context
    # @raise [VAOS::Exceptions::BackendServiceException] If response contains error field
    # @return [void]
    #
    def check_for_eps_error!(response_data, response, method_name = nil)
      error_value = extract_error_from_response(response_data)
      return unless error_value

      # Log the error without PII - only include safe context information
      method_name ||= caller_locations(1, 1)[0].label
      Rails.logger.warn("#{CC_APPOINTMENTS}: EPS appointment error", {
                          error_type: error_value,
                          method: method_name,
                          status: response.status || 'unknown',
                          controller: controller_name,
                          station_number:,
                          eps_trace_id:
                        })

      raise_eps_error(error_value, response)
    end

    def handle_eps_error!(e, method_name)
      error_context = {
        service: 'EPS',
        method: method_name,
        error_class: e.class.name,
        timestamp: Time.current.iso8601,
        controller: controller_name,
        station_number:,
        eps_trace_id:
      }.merge(parse_eps_backend_fields(e.message.to_s)).compact

      Rails.logger.error("#{CC_APPOINTMENTS}: EPS service error", error_context)
    end

    private

    ##
    # Returns the controller name from RequestStore for logging context
    #
    # @return [String, nil] The controller name or nil if not set
    #
    def controller_name
      RequestStore.store['controller_name']
    end

    ##
    # Returns the user's primary station number (first treatment facility ID) for logging context
    #
    # @return [String, nil] The station number or nil if not available
    #
    def station_number
      user&.va_treatment_facility_ids&.first
    end

    ##
    # Returns the EPS trace ID from RequestStore
    #
    # @return [String, nil] The trace ID or nil if not set
    #
    def eps_trace_id
      RequestStore.store['eps_trace_id']
    end

    def parse_eps_backend_fields(raw_message)
      # Extract code from the top level
      code = raw_message[/:code=>"([^"]+)"/, 1]

      # Extract status from the source hash
      status = raw_message[/:vamf_status=>(\d+)/, 1]&.to_i

      # Extract body from the source hash - need to handle escaped quotes
      body = raw_message[/:vamf_body=>"((?:\\.|[^"\\])*)"/, 1]

      # Only return the fields we actually want to log
      result = {}
      result[:code] = code if code
      result[:upstream_status] = status if status
      result[:upstream_body] = sanitize_response_body(body) if body

      result
    end

    def sanitize_response_body(body)
      return nil if body.nil?

      # Use VAOS anonymization pattern for consistency with other VAOS services
      VAOS::Anonymizers.anonymize_icns(body.to_s)
    end

    ##
    # Get appropriate headers with correlation ID based on whether mocks are enabled.
    # With Betamocks we bypass the need to request tokens and correlation IDs.
    #
    # @return [Hash] Headers with correlation ID for the request or empty hash if mocks are enabled
    #
    def request_headers_with_correlation_id
      config.mock_enabled? ? {} : headers_with_correlation_id
    end

    ##
    # Returns the patient ID for the current user.
    #
    # @return [String] The ICN of the current user.
    def patient_id
      @patient_id ||= user.icn
    end

    ##
    # Extracts error value from various response data formats
    #
    # @param response_data [Object] The response data to check
    # @return [String, nil] The error value if present, nil otherwise
    #
    def extract_error_from_response(response_data)
      case response_data
      when OpenStruct
        response_data.error if response_data.respond_to?(:error) && response_data.error.present?
      when Hash
        response_data[:error].presence
      end
    end

    ##
    # Raises a VAOS::Exceptions::BackendServiceException for EPS error responses
    #
    # @param error_message [String] The error message from the EPS response
    # @param response [Object] The HTTP response object
    # @raise [VAOS::Exceptions::BackendServiceException]
    #
    def raise_eps_error(error_message, _response)
      status_code = map_error_to_status_code(error_message)
      sanitized_body = build_sanitized_error_body(error_message)
      mock_env = build_mock_env(status_code, sanitized_body)

      raise VAOS::Exceptions::BackendServiceException, mock_env
    end

    ##
    # Maps error message to appropriate HTTP status code
    #
    # @param error_message [String] The error message from EPS
    # @return [Integer] The HTTP status code
    #
    def map_error_to_status_code(error_message)
      case error_message
      when 'conflict'
        409  # HTTP 409 Conflict
      when 'bad-request'
        400  # HTTP 400 Bad Request
      when 'internal-error'
        500  # HTTP 500 Internal Server Error
      else
        422  # HTTP 422 Unprocessable Entity (default for other business logic errors)
      end
    end

    ##
    # Builds a sanitized error body that doesn't contain PII
    #
    # @param error_message [String] The error message from EPS
    # @return [String] JSON string of sanitized error body
    #
    def build_sanitized_error_body(error_message)
      {
        error: error_message,
        source: 'EPS service',
        timestamp: Time.current.iso8601
      }.to_json
    end

    ##
    # Builds a mock environment object for VAOS exception
    #
    # @param status_code [Integer] The HTTP status code
    # @param sanitized_body [String] The sanitized error body JSON
    # @return [OpenStruct] Mock environment object
    #
    def build_mock_env(status_code, sanitized_body)
      OpenStruct.new(
        status: status_code,
        body: sanitized_body,
        url: "#{config.api_url}/#{config.base_path}",
        response_body: sanitized_body
      )
    end
  end
end
