# frozen_string_literal: true

module UnifiedHealthData
  # Detects OperationOutcome resources in SCDF responses, distinguishing between
  # error-level issues (partial failures) and warning-level issues (e.g., missing Binary resources).
  #
  # Error-level OperationOutcomes indicate a data source failed entirely and should raise exceptions.
  # Warning-level OperationOutcomes indicate partial data loss (e.g., a Binary attachment not found)
  # and should be surfaced to the frontend alongside the successfully retrieved data.
  #
  # @example Basic usage
  #   detector = OperationOutcomeDetector.new(response_body)
  #   if detector.partial_failure?
  #     raise Common::Exceptions::UpstreamPartialFailure.new(...)
  #   end
  #   if detector.warnings?
  #     # attach warning_details to response for downstream consumption
  #   end
  #
  class OperationOutcomeDetector
    STATSD_KEY_PREFIX = 'api.uhd.partial_failure'
    STATSD_WARNING_KEY_PREFIX = 'api.uhd.partial_warning'
    ERROR_SEVERITIES = %w[error fatal].freeze
    WARNING_SEVERITIES = %w[warning].freeze

    attr_reader :body, :failure_details, :failed_sources, :warning_details

    # @param body [Hash] The response body from SCDF containing vista and oracle-health keys
    def initialize(body)
      @body = body
      @failed_sources = []
      @failure_details = []
      @warning_details = []
      detect_issues if @body.is_a?(Hash)
    end

    # @return [Boolean] true if any OperationOutcome with error/fatal severity was found
    def partial_failure?
      @failure_details.any?
    end

    # @return [Boolean] true if any OperationOutcome with warning severity was found
    def warnings?
      @warning_details.any?
    end

    # Logs the partial failure details and increments StatsD metrics
    # @param user [User] Optional user for context in logs
    # @param resource_type [String] The type of resource being fetched (e.g., 'medications', 'allergies')
    def log_and_track(user: nil, resource_type: 'unknown')
      return unless partial_failure?

      log_failure_details(user, resource_type)
      track_metrics(resource_type)
    end

    # Logs warning details and increments StatsD metrics for warning-level OperationOutcomes
    # @param user [User] Optional user for context in logs
    # @param resource_type [String] The type of resource being fetched
    def log_and_track_warnings(user: nil, resource_type: 'unknown')
      return unless warnings?

      log_warning_details(user, resource_type)
      track_warning_metrics(resource_type)
    end

    private

    def detect_issues
      detect_issues_in_source('vista')
      detect_issues_in_source('oracle-health')
    end

    def detect_issues_in_source(source)
      source_data = @body[source]
      return unless source_data

      entries = extract_entries(source_data)
      entries.each do |entry|
        resource = entry['resource'] || entry
        next unless operation_outcome?(resource)

        classify_issues(resource, source)
      end
    end

    def extract_entries(source_data)
      source_data['entry'] || []
    end

    def operation_outcome?(resource)
      resource['resourceType'] == 'OperationOutcome'
    end

    def classify_issues(resource, source)
      issues = resource['issue'] || []
      issues.each do |issue|
        detail = {
          source:,
          code: issue['code'],
          diagnostics: issue['diagnostics'],
          severity: issue['severity']
        }

        if ERROR_SEVERITIES.include?(issue['severity'])
          @failure_details << detail
          @failed_sources << source unless @failed_sources.include?(source)
        elsif WARNING_SEVERITIES.include?(issue['severity'])
          @warning_details << detail
        end
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

    def log_warning_details(user, resource_type)
      warning_sources = @warning_details.map { |d| d[:source] }.uniq
      Rails.logger.warn(
        message: 'UHD upstream source returned OperationOutcome warning',
        resource_type:,
        warning_sources:,
        warning_count: @warning_details.size,
        user_uuid: user&.uuid,
        details: @warning_details.map { |d| { source: d[:source], code: d[:code], diagnostics: d[:diagnostics] } }
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

    def track_warning_metrics(resource_type)
      warning_sources = @warning_details.map { |d| d[:source] }.uniq
      warning_sources.each do |source|
        StatsD.increment(
          STATSD_WARNING_KEY_PREFIX,
          tags: ["source:#{source}", "resource_type:#{resource_type}"]
        )
      end
    end
  end
end
