# frozen_string_literal: true

require 'logging/base_monitor'

module Form210779
  ##
  # Monitor class for tracking Form 21-0779 validation and submission events
  #
  # Provides methods for tracking validation failures and other
  # form-related events with StatsD metrics and structured logging.
  #
  class Monitor < ::Logging::BaseMonitor
    SERVICE_NAME = 'form210779'
    FORM_ID = '21-0779'
    CLAIM_STATS_KEY = 'api.form210779'
    SUBMISSION_STATS_KEY = 'worker.lighthouse.form210779_intake_job'

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
    # Logs validation failures from ActiveRecord
    #
    # Form 21-0779 does not use Committee middleware for validation.
    # This tracks ActiveRecord validation errors when claim.save fails.
    #
    # Note: Rails handles malformed JSON at middleware level (returns 400),
    # so JSON parse errors never reach the controller.
    #
    # @param error [Common::Exceptions::ValidationErrors] The validation error
    # @param request [Rack::Request] The incoming request
    # @param claim [SavedClaim::Form210779] The claim object with validation errors
    def track_request_validation_error(error:, request:, claim: nil)
      call_location = caller_locations.first

      validation_details = extract_validation_details_from_error(error, claim)

      track_request(
        :warn,
        "#{self.class.name} #{FORM_ID} validation failed: #{validation_details[:error_type]}",
        "#{CLAIM_STATS_KEY}.validation_error",
        call_location:,
        form_id: FORM_ID,
        path: request.path,
        method: request.request_method,
        source_app: extract_source_app(request),
        error_type: validation_details[:error_type],
        data_pointer: validation_details[:data_pointer]
      )
    end

    # Required BaseMonitor abstract method implementations
    def claim_stats_key
      CLAIM_STATS_KEY
    end

    def submission_stats_key
      SUBMISSION_STATS_KEY
    end

    def name
      SERVICE_NAME
    end

    def form_id
      FORM_ID
    end

    ##
    # Track submission begun in controller
    # Called when submission processing starts, before validation and persistence
    #
    # @param claim [SavedClaim::Form210779]
    # @param user_uuid [String, nil] Optional user UUID for tracking
    def track_submission_begun(claim, user_uuid: nil)
      submit_event(
        :info,
        "#{message_prefix} submission begun",
        "#{SUBMISSION_STATS_KEY}.begun",
        claim:,
        user_uuid:,
        claim_guid: claim&.guid
      )
    end

    ##
    # Track successful submission
    # Called when claim is successfully validated, saved, and attachments processed
    #
    # @param claim [SavedClaim::Form210779]
    # @param user_uuid [String, nil] Optional user UUID for tracking
    def track_submission_success(claim, user_uuid: nil)
      submit_event(
        :info,
        "#{message_prefix} submission success",
        "#{SUBMISSION_STATS_KEY}.success",
        claim:,
        user_uuid:,
        claim_guid: claim&.guid
      )
    end

    ##
    # Track submission failure
    # Called when claim validation or save fails in the controller action
    #
    # @param claim [SavedClaim::Form210779]
    # @param error [StandardError] The error that occurred
    # @param user_uuid [String, nil] Optional user UUID for tracking
    def track_submission_failure(claim, error, user_uuid: nil)
      submit_event(
        :error,
        "#{message_prefix} submission failure: #{error.class}",
        "#{SUBMISSION_STATS_KEY}.failure",
        claim:,
        user_uuid:,
        claim_guid: claim&.guid,
        error_class: error.class.name,
        error_message: error.message
      )
    end

    ##
    # Track HTTP response codes for API endpoint monitoring
    # Enables response code distribution tracking in Datadog
    #
    # @param code [Integer] HTTP status code (200, 422, 429, 500, etc.)
    # @param action [String, nil] Optional action name (e.g., 'create', 'download_pdf')
    # @param user_uuid [String, nil] Optional user UUID for correlation
    # @param claim_guid [String, nil] Optional claim GUID for correlation
    def track_request_code(code, action: nil, user_uuid: nil, claim_guid: nil)
      submit_event(
        :info,
        "#{message_prefix} request completed with status #{code}",
        "#{CLAIM_STATS_KEY}.request",
        code:,
        action:,
        user_uuid:,
        claim_guid:
      )
    end

    private

    def message_prefix
      "#{SERVICE_NAME}:#{FORM_ID}"
    end

    ##
    # Extracts validation details from ActiveRecord errors without exposing PII
    #
    # @param error [Common::Exceptions::ValidationErrors] The validation error
    # @param claim [SavedClaim::Form210779] The claim object with validation errors
    # @return [Hash] Hash with :error_type and :data_pointer
    def extract_validation_details_from_error(error, claim)
      # Debug log for local development (suppressed in production)
      Rails.logger.debug { "[#{self.class.name}] Validation error: #{error.class} - #{error.message}" }

      {
        error_type: 'activerecord_validation',
        data_pointer: extract_data_pointer_from_claim(claim)
      }
    end

    ##
    # Extracts field path from ActiveRecord validation errors
    #
    # @param claim [SavedClaim::Form210779, nil] The claim object
    # @return [String] The field path or 'unknown'
    def extract_data_pointer_from_claim(claim)
      return 'unknown' unless claim&.errors&.any?

      # Get first error's attribute path
      first_error_key = claim.errors.attribute_names.first
      first_error_key.to_s.presence || 'unknown'
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
