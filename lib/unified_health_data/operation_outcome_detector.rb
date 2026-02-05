# frozen_string_literal: true

module UnifiedHealthData
  # Detects OperationOutcome resources with error severity in SCDF responses
  # Used to identify partial failures when one or more data sources fail
  # while others succeed (e.g., Oracle Health rate limited while VistA succeeds)
  #
  # @example Basic usage
  #   detector = OperationOutcomeDetector.new(response_body)
  #   if detector.partial_failure?
  #     Rails.logger.warn("Partial failure detected: #{detector.failure_details}")
  #     raise Common::Exceptions::UpstreamPartialFailure.new(
  #       failed_sources: detector.failed_sources,
  #       failure_details: detector.failure_details
  #     )
  #   end
  #
  class OperationOutcomeDetector
    STATSD_KEY_PREFIX = 'api.uhd.partial_failure'
    ERROR_SEVERITIES = %w[error fatal].freeze

    attr_reader :body, :failure_details, :failed_sources

    # @param body [Hash] The response body from SCDF containing vista and oracle-health keys
    def initialize(body)
      @body = body
      @failed_sources = []
      @failure_details = []
      detect_failures if @body
    end

    # @return [Boolean] true if any OperationOutcome with severity: error was found
    def partial_failure?
      @failure_details.any?
    end

    # Logs the partial failure details and increments StatsD metrics
    # @param user [User] Optional user for context in logs
    # @param resource_type [String] The type of resource being fetched (e.g., 'medications', 'allergies')
    def log_and_track(user: nil, resource_type: 'unknown')
      return unless partial_failure?

      log_failure_details(user, resource_type)
      track_metrics(resource_type)
    end

    private

    def detect_failures
      detect_failures_in_source('vista')
      detect_failures_in_source('oracle-health')
    end

    def detect_failures_in_source(source)
      source_data = @body[source]
      return unless source_data

      entries = extract_entries(source_data)
      entries.each do |entry|
        resource = entry['resource'] || entry
        next unless operation_outcome?(resource)

        extract_error_issues(resource, source)
      end
    end

    def extract_entries(source_data)
      # SCDF returns OperationOutcome errors in the 'entry' array for all endpoints.
      # Actual medication data may be in 'medicationList', but errors are always in 'entry'.
      source_data['entry'] || []
    end

    def operation_outcome?(resource)
      resource['resourceType'] == 'OperationOutcome'
    end

    def extract_error_issues(resource, source)
      issues = resource['issue'] || []
      issues.each do |issue|
        next unless ERROR_SEVERITIES.include?(issue['severity'])

        @failure_details << {
          source:,
          code: issue['code'],
          diagnostics: issue['diagnostics'],
          severity: issue['severity']
        }
        @failed_sources << source unless @failed_sources.include?(source)
      end
    end

    def log_failure_details(user, resource_type)
      Rails.logger.warn(
        message: 'UHD upstream source returned OperationOutcome error',
        resource_type:,
        failed_sources: @failed_sources,
        failure_count: @failure_details.size,
        user_uuid: user&.uuid,
        details: @failure_details.map { |d| { source: d[:source], code: d[:code], diagnostics: d[:diagnostics] } }
      )
    end

    def track_metrics(resource_type)
      @failed_sources.each do |source|
        StatsD.increment(
          STATSD_KEY_PREFIX,
          tags: ["source:#{source}", "resource_type:#{resource_type}"]
        )
      end
    end
  end
end
