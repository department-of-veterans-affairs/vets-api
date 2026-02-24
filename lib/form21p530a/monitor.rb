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
    SUBMISSION_STATS_KEY = 'worker.lighthouse.form21p530a_intake_job'

    # Parameters allowed in logs (no PII)
    ALLOWLIST = %w[
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
    def submission_stats_key = SUBMISSION_STATS_KEY
    def name = SERVICE_NAME
    def form_id = FORM_ID

    ##
    # Track submission begun in controller
    # Called when claim is saved and about to be queued to Sidekiq
    def track_submission_begun(claim, user_uuid: nil)
      submit_event(:info, "#{message_prefix} submission begun", "#{SUBMISSION_STATS_KEY}.begun",
                   claim:, user_uuid:, claim_guid: claim&.guid)
    end

    ##
    # Track successful submission in controller
    # Called when claim is successfully saved and queued
    def track_submission_success(claim, user_uuid: nil)
      submit_event(:info, "#{message_prefix} submission success", "#{SUBMISSION_STATS_KEY}.success",
                   claim:, user_uuid:, claim_guid: claim&.guid)
    end

    ##
    # Track submission failure in controller
    # Called when claim save or processing fails
    def track_submission_failure(claim, error, user_uuid: nil)
      submit_event(:error, "#{message_prefix} submission failure: #{error.class}",
                   "#{SUBMISSION_STATS_KEY}.failure",
                   claim:, user_uuid:, claim_guid: claim&.guid,
                   error_class: error.class.name, error_message: error.message)
    end

    ##
    # Track HTTP response codes for API endpoint monitoring
    # Enables response code distribution tracking in Datadog
    def track_request_code(code)
      submit_event(:info, "#{message_prefix} request completed with status #{code}",
                   "#{CLAIM_STATS_KEY}.request", code:)
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
