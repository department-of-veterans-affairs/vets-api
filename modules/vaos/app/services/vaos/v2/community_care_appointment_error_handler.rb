# frozen_string_literal: true

# Define Eps::ServiceException if not already defined
module Eps
  class ServiceException < Common::Exceptions::BackendServiceException; end unless defined?(Eps::ServiceException)
end

module VAOS
  module V2
    ##
    # CommunityCareAppointmentErrorHandler - Unified error handling for Community Care appointments
    #
    # This service normalizes all error types (business logic errors, backend service exceptions,
    # parameter validation errors, Redis errors, etc.) into a consistent error response format.
    # It provides rich metadata for debugging while ensuring no PII is exposed in error responses.
    #
    # @example Basic usage
    #   error_response = CommunityCareAppointmentErrorHandler.handle(
    #     error,
    #     context: { operation: 'create_draft', referral_id: 'REF-123' }
    #   )
    #   render json: error_response[:response], status: error_response[:status]
    #
    class CommunityCareAppointmentErrorHandler
      include VAOS::CommunityCareConstants

      ##
      # Handle an error and return a standardized response
      #
      # @param error [Object] The error to handle (Hash, Exception, etc.)
      # @param context [Hash] Additional context about the operation
      # @option context [String] :operation The operation being performed ('create_draft', 'submit')
      # @option context [String] :referral_id The referral ID (for logging context only)
      # @option context [String] :referral_number The referral number (for logging context only)
      # @return [Hash] Hash with :response and :status keys
      #
      def self.handle(error, context: {})
        new(error, context).handle
      end

      def initialize(error, context)
        @error = error
        @context = context
      end

      ##
      # Process the error and return formatted response
      #
      # @return [Hash] Hash containing :response (JSON structure) and :status (HTTP status code)
      #
      def handle
        {
          response: build_error_response,
          status: determine_status_code
        }
      end

      private

      ##
      # Build the standardized error response structure
      #
      # @return [Hash] Error response with errors array
      #
      def build_error_response
        {
          errors: [{
            title: error_title,
            detail: error_detail,
            code: error_code,
            meta: error_metadata
          }.compact]
        }
      end

      ##
      # Determine the appropriate error title based on error type
      #
      # @return [String] Human-readable error category
      #
      def error_title
        if @error.is_a?(Hash)
          'Community Care appointment operation failed'
        elsif backend_service_exception?
          'External service error'
        elsif @error.is_a?(ActionController::ParameterMissing)
          'Invalid request parameters'
        elsif @error.is_a?(Redis::BaseError)
          'Service temporarily unavailable'
        elsif @error.is_a?(ArgumentError)
          'Invalid parameters'
        else
          'Unexpected error occurred'
        end
      end

      ##
      # Extract the specific error detail message
      #
      # @return [String] Detailed error message
      #
      def error_detail
        if @error.is_a?(Hash)
          @error[:message]
        elsif backend_service_exception?
          extract_backend_service_detail
        elsif @error.is_a?(ActionController::ParameterMissing)
          "Required parameter missing: #{@error.param}"
        elsif @error.is_a?(Redis::BaseError)
          'Unable to connect to cache service. Please try again.'
        elsif @error.is_a?(ArgumentError)
          # ArgumentError message is safe - it's our own validation message
          @error.class.name
        else
          'An unexpected error occurred. Please try again.'
        end
      end

      ##
      # Check if error is a backend service exception
      #
      # @return [Boolean] True if error responds to backend service exception methods
      #
      def backend_service_exception?
        @error.respond_to?(:original_status) &&
          @error.respond_to?(:original_body) &&
          @error.respond_to?(:response_values)
      end

      ##
      # Extract detail from backend service exception
      #
      # @return [String] Error detail from backend service
      #
      def extract_backend_service_detail
        # Try to get detail from response_values first
        detail = @error.response_values&.dig(:detail)
        return detail if detail.present?

        # Fall back to extracting from original_body if it's JSON
        extract_detail_from_body(@error.original_body)
      end

      ##
      # Extract detail from error body
      #
      # @param body [String, Hash] Error response body
      # @return [String] Extracted detail or generic message
      #
      def extract_detail_from_body(body)
        return 'Service error occurred' unless body

        parsed = body.is_a?(String) ? JSON.parse(body) : body
        parsed.dig('errors', 0, 'errorMessage') || parsed['message'] || 'Service error occurred'
      rescue JSON::ParserError
        'Service error occurred'
      end

      ##
      # Determine the error code for the response
      #
      # @return [String, nil] Error code or nil
      #
      def error_code
        if @error.is_a?(Hash)
          map_business_logic_error_to_code
        elsif backend_service_exception?
          map_backend_service_error_to_code
        elsif @error.is_a?(ActionController::ParameterMissing)
          'INVALID_REQUEST_PARAMETERS'
        elsif @error.is_a?(Redis::BaseError)
          'CACHE_SERVICE_UNAVAILABLE'
        elsif @error.is_a?(ArgumentError)
          'INVALID_ARGUMENT'
        else
          'UNEXPECTED_ERROR'
        end
      end

      ##
      # Map business logic error (from CreateEpsDraftAppointment) to error code
      #
      # @return [String] Error code
      #
      def map_business_logic_error_to_code
        # Use code from error hash if provided (preferred)
        return @error[:code] if @error[:code].present?

        # Fallback to message matching for backwards compatibility
        message = @error[:message].to_s.downcase
        code = case message
               when /user authentication required/ then 'DRAFT_AUTHENTICATION_REQUIRED'
               when /missing required parameters/ then 'DRAFT_MISSING_PARAMETERS'
               when /required referral data is missing/ then 'DRAFT_REFERRAL_INVALID'
               when /error checking existing appointments/ then 'DRAFT_APPOINTMENT_CHECK_FAILED'
               when /referral is already used/ then 'DRAFT_REFERRAL_ALREADY_USED'
               when /provider not found/ then 'DRAFT_PROVIDER_NOT_FOUND'
               when /could not create draft appointment/ then 'DRAFT_CREATION_FAILED'
               when /appointment already exists/ then 'SUBMIT_APPOINTMENT_CONFLICT'
               end

        code || fallback_error_code
      end

      ##
      # Get fallback error code based on operation type
      #
      # @return [String] Fallback error code
      #
      def fallback_error_code
        @context[:operation] == 'submit' ? 'SUBMIT_FAILED' : 'DRAFT_FAILED'
      end

      ##
      # Map backend service exception to error code
      #
      # @return [String] Error code
      #
      def map_backend_service_error_to_code
        service_name = extract_service_name(@error)
        status = @error.original_status

        case service_name
        when 'EPS'
          map_eps_error_code(status)
        when 'VAOS'
          map_vaos_error_code(status)
        when 'CCRA'
          map_ccra_error_code(status)
        else
          'BACKEND_SERVICE_ERROR'
        end
      end

      ##
      # Map EPS service errors to codes
      #
      # @param status [Integer, nil] HTTP status code
      # @return [String] Error code
      #
      def map_eps_error_code(status)
        return 'EPS_ERROR' unless status

        case status
        when 400 then 'EPS_BAD_REQUEST'
        when 404 then 'EPS_NOT_FOUND'
        when 409 then 'EPS_CONFLICT'
        when 500..599 then 'EPS_SERVICE_UNAVAILABLE'
        else 'EPS_ERROR'
        end
      end

      ##
      # Map VAOS service errors to codes
      #
      # @param status [Integer, nil] HTTP status code
      # @return [String] Error code
      #
      def map_vaos_error_code(status)
        return 'VAOS_ERROR' unless status

        case status
        when 400 then 'VAOS_BAD_REQUEST'
        when 404 then 'VAOS_NOT_FOUND'
        when 409 then 'VAOS_CONFLICT'
        when 500..599 then 'VAOS_SERVICE_UNAVAILABLE'
        else 'VAOS_ERROR'
        end
      end

      ##
      # Map CCRA service errors to codes
      #
      # @param status [Integer, nil] HTTP status code
      # @return [String] Error code
      #
      def map_ccra_error_code(status)
        return 'CCRA_ERROR' unless status

        case status
        when 400 then 'CCRA_BAD_REQUEST'
        when 404 then 'CCRA_REFERRAL_NOT_FOUND'
        when 500..599 then 'CCRA_SERVICE_UNAVAILABLE'
        else 'CCRA_ERROR'
        end
      end

      ##
      # Build metadata object for error response
      #
      # @return [Hash, nil] Metadata hash or nil if no metadata
      #
      def error_metadata
        meta = {
          operation: @context[:operation]
        }.compact

        if backend_service_exception?
          add_backend_service_metadata(meta)
        elsif @error.is_a?(Hash)
          add_business_logic_metadata(meta)
        end

        meta.presence
      end

      ##
      # Add metadata for backend service exceptions
      #
      # @param meta [Hash] Metadata hash to populate
      # @return [void]
      #
      def add_backend_service_metadata(meta)
        meta[:backend_service] = extract_service_name(@error)
        meta[:original_status] = @error.original_status if @error.original_status.present?
        detail = @error.response_values&.dig(:detail)
        meta[:backend_detail] = detail if detail.present?
      end

      ##
      # Add metadata for business logic errors
      #
      # @param meta [Hash] Metadata hash to populate
      # @return [void]
      #
      def add_business_logic_metadata(meta)
        meta[:reason] = @error[:status] if @error[:status]
      end

      ##
      # Determine the HTTP status code for the response
      #
      # @return [Symbol] HTTP status code symbol
      #
      def determine_status_code
        if @error.is_a?(Hash)
          @error[:status]
        elsif backend_service_exception?
          map_backend_status_code(@error.original_status)
        elsif @error.is_a?(ActionController::ParameterMissing) || @error.is_a?(ArgumentError)
          :bad_request
        elsif @error.is_a?(Redis::BaseError)
          :bad_gateway
        else
          :internal_server_error
        end
      end

      ##
      # Map backend service status codes to appropriate HTTP status
      #
      # @param original_status [Integer, nil] Original status from backend
      # @return [Symbol, Integer] Mapped status code
      #
      def map_backend_status_code(original_status)
        return :bad_gateway unless original_status

        case original_status
        when 400 then :bad_request
        when 401 then :unauthorized
        when 403 then :forbidden
        when 404 then :not_found
        when 409 then :conflict
        when 422 then :unprocessable_entity
        when 500..599 then :bad_gateway
        else
          original_status.between?(400, 499) ? original_status : :bad_gateway
        end
      end

      ##
      # Extract service name from backend exception
      #
      # @param error [Common::Exceptions::BackendServiceException] The exception
      # @return [String] Service name ('EPS', 'VAOS', 'CCRA', or 'Unknown')
      #
      def extract_service_name(error)
        # Check class name for EPS
        if error.is_a?(Eps::ServiceException) || error.class.name.include?('Eps::ServiceException')
          'EPS'
        else
          # Try to extract from error key or original body
          key_str = error.respond_to?(:key) ? error.key.to_s : ''
          if key_str.start_with?('VAOS') || key_str.include?('VAOS')
            'VAOS'
          elsif key_str.start_with?('CCRA') || key_str.include?('CCRA') || error.original_body&.to_s&.include?('ccra')
            'CCRA'
          else
            'Unknown'
          end
        end
      end
    end
  end
end
