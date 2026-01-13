# frozen_string_literal: true

require 'logging/monitor'

module Form214192
  ##
  # Monitor class for tracking Form 21-4192 validation and submission events
  #
  # Provides methods for tracking Committee validation failures and other
  # form-related events with StatsD metrics and structured logging.
  #
  class Monitor < ::Logging::Monitor
    SERVICE_NAME = 'form214192'
    FORM_ID = '21-4192'
    STATS_KEY = 'api.form214192'

    # Parameters allowed in logs (no PII)
    ALLOWLIST = %w[
      data_pointer
      error_type
      form_id
      method
      path
      source_app
    ].freeze

    def initialize
      super(SERVICE_NAME, allowlist: ALLOWLIST)
    end

    ##
    # Logs Committee request validation failures
    #
    # Called when Committee middleware rejects a request that doesn't conform
    # to the OpenAPI schema. Logs the field path and error type without PII.
    #
    # @param error [Committee::InvalidRequest] The validation error from Committee
    # @param request [Rack::Request] The incoming request
    def track_request_validation_error(error:, request:)
      call_location = caller_locations.first

      validation_details = extract_validation_details(error)

      track_request(
        :warn,
        "#{self.class.name} #{FORM_ID} Committee validation failed",
        "#{STATS_KEY}.validation_error",
        call_location:,
        form_id: FORM_ID,
        path: request.path,
        method: request.request_method,
        source_app: extract_source_app(request),
        error_type: validation_details[:error_type],
        data_pointer: validation_details[:data_pointer]
      )
    end

    private

    ##
    # Extracts validation details from Committee error without exposing PII
    #
    # @param error [Committee::InvalidRequest] The validation error
    # @return [Hash] Hash with :error_type and :data_pointer
    def extract_validation_details(error)
      message = error.message.to_s

      # Debug log for local development (suppressed in production)
      Rails.logger.debug { "[#{self.class.name}] Committee error: #{message}" }

      {
        error_type: extract_error_type(message),
        data_pointer: extract_data_pointer(message)
      }
    end

    ##
    # Extracts the error type from Committee error message
    #
    # @param message [String] The error message
    # @return [String] The error type (e.g., 'pattern', 'required', 'type')
    def extract_error_type(message)
      case message
      when /pattern.*does not match/i
        'pattern_mismatch'
      when /required/i
        'missing_required'
      when /is not a member of enum/i
        'invalid_enum'
      when /expected.*got/i, /type mismatch/i
        'type_mismatch'
      when /minimum|maximum/i
        'out_of_range'
      when /minLength|maxLength/i
        'invalid_length'
      else
        'validation_error'
      end
    end

    ##
    # Extracts the field path (data pointer) from Committee error message
    #
    # Removes PII by extracting only the schema path, not user values.
    #
    # @param message [String] The error message
    # @return [String, nil] The field path or nil if not found
    def extract_data_pointer(message)
      # Committee errors often include the path in formats like:
      # "#/properties/veteranInformation/properties/ssn pattern..."
      # or "/veteranInformation/ssn"
      if (match = message.match(%r{#/[^\s]+|/[a-zA-Z][a-zA-Z0-9/]*}))
        # Clean up the path to remove schema-specific parts
        path = match[0]
        path = path.gsub(%r{#/paths/[^/]+/[^/]+/requestBody/content/[^/]+/schema}, '')
        path = path.gsub('/properties/', '/')
        path = path.gsub(%r{^/+}, '/')
        path.presence || 'unknown'
      else
        'unknown'
      end
    end

    ##
    # Extracts source app from request headers
    #
    # @param request [Rack::Request] The incoming request
    # @return [String] The source app name or 'unknown'
    def extract_source_app(request)
      request.env['SOURCE_APP'] || request.env['HTTP_X_SOURCE_APP'] || 'unknown'
    end
  end
end
