# frozen_string_literal: true

require 'logging/base_monitor'

module Form21p530a
  ##
  # Monitor class for tracking Form 21P-530A validation and submission events
  #
  # Provides methods for tracking Committee validation failures and other
  # form-related events with StatsD metrics and structured logging.
  class Monitor < ::Logging::BaseMonitor
    SERVICE_NAME = 'form21p530a'
    FORM_ID = '21P-530A'
    CLAIM_STATS_KEY = 'api.form21p530a'

    # Parameters allowed in logs (no PII)
    ALLOWLIST = %w[
      action
      data_pointer
      error_type
      method
      path
      source_app
      code
      user_uuid
      claim_guid
    ].freeze

    def initialize
      super(SERVICE_NAME, allowlist: ALLOWLIST)
    end

    ##
    # Logs Committee request validation failures
    #
    # Called when Committee middleware rejects a request that doesn't conform
    # to the OpenAPI schema. Logs the field path and error type without PII.
    def track_request_validation_error(error:, request:)
      validation_details = extract_validation_details(error)

      track_request(
        :warn,
        "#{self.class.name} #{FORM_ID} Committee validation failed",
        "#{CLAIM_STATS_KEY}.validation_error",
        call_location: caller_locations.first,
        form_id: FORM_ID,
        path: request.path,
        method: request.request_method,
        source_app: extract_source_app(request),
        error_type: validation_details[:error_type],
        data_pointer: validation_details[:data_pointer]
      )
    end

    # Required BaseMonitor abstract method implementations
    def claim_stats_key = CLAIM_STATS_KEY
    def name = SERVICE_NAME
    def form_id = FORM_ID

    ##
    # Track submission begun in controller
    # Called when submission processing starts, before validation and persistence
    def track_submission_begun(claim, user_uuid: nil)
      submit_event(:info, "#{message_prefix} submission begun", "#{CLAIM_STATS_KEY}.submission.begun",
                   claim:, user_uuid:, claim_guid: claim&.guid)
    end

    ##
    # Track successful submission in controller
    # Called when claim is successfully validated, saved,
    # and attachments processed
    def track_submission_success(claim, user_uuid: nil)
      submit_event(:info, "#{message_prefix} submission success", "#{CLAIM_STATS_KEY}.submission.success",
                   claim:, user_uuid:, claim_guid: claim&.guid)
    end

    ##
    # Track submission failure in controller
    # Called when claim validation or save fails in the controller action
    def track_submission_failure(claim, error, user_uuid: nil)
      submit_event(:error, "#{message_prefix} submission failure: #{error.class}",
                   "#{CLAIM_STATS_KEY}.submission.failure",
                   claim:, user_uuid:, claim_guid: claim&.guid,
                   error_class: error.class.name, error_message: error.message)
    end

    ##
    # Track HTTP response codes for API endpoint monitoring
    # Enables response code distribution tracking in Datadog
    #
    # @param code [Integer] HTTP status code (200, 422, 429, 500, etc.)
    # @param action [String, nil] Optional action name
    #   (e.g., 'create', 'download_pdf')
    # @param user_uuid [String, nil] Optional user UUID for correlation
    # @param claim_guid [String, nil] Optional claim GUID for correlation
    def track_request_code(code, action: nil, user_uuid: nil, claim_guid: nil)
      submit_event(:info, "#{message_prefix} request completed with status #{code}",
                   "#{CLAIM_STATS_KEY}.request", code:, action:, user_uuid:, claim_guid:)
    end

    ##
    # Track PDF generation success with timing
    #
    # @param start_time [Time] When PDF generation started
    def track_pdf_generation_success(start_time)
      duration_ms = (Time.current - start_time) * 1000
      StatsD.measure("#{CLAIM_STATS_KEY}.pdf_generation.duration", duration_ms)

      submit_event(
        :info,
        "#{message_prefix} PDF generation success",
        "#{CLAIM_STATS_KEY}.pdf_generation.success",
        pdf_generation_duration_ms: duration_ms.round(2)
      )
    end

    ##
    # Track PDF generation failure
    #
    # @param error [Exception] The error that occurred
    def track_pdf_generation_failure(error)
      submit_event(
        :error,
        "#{message_prefix} PDF generation failure: #{error.class}",
        "#{CLAIM_STATS_KEY}.pdf_generation.failure",
        error_class: error.class.name,
        error_message: error.message
      )
    end

    private

    def message_prefix = "#{SERVICE_NAME}:#{FORM_ID}"

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
