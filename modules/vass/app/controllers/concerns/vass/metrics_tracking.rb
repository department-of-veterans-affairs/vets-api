# frozen_string_literal: true

module Vass
  ##
  # Concern for tracking StatsD metrics in VASS controllers.
  #
  # Provides consistent metric tracking with standardized naming and tagging.
  # All metrics follow the pattern: api.vass.controller.{controller}.{action}.{outcome}
  #
  # @example Track a successful operation
  #   track_success(APPOINTMENTS_CREATE)
  #
  # @example Track a failure
  #   track_failure(APPOINTMENTS_CREATE, error_type: exception.class.name)
  #
  # @example Track an infrastructure event
  #   track_infrastructure_metric(SESSION_OTP_GENERATED)
  #
  module MetricsTracking
    extend ActiveSupport::Concern
    include Vass::MetricsConstants

    private

    ##
    # Records a success metric for a controller action.
    # Automatically includes standard tags.
    #
    # @param metric_base [String] Base metric name (e.g., APPOINTMENTS_CREATE)
    # @param additional_tags [Hash] Optional additional tags
    #
    # @example
    #   track_success(APPOINTMENTS_CREATE)
    #
    def track_success(metric_base, additional_tags: {})
      http_status = response.respond_to?(:status) ? response.status : nil
      tags = build_metric_tags(http_status:, additional_tags:)

      StatsD.increment("#{metric_base}.#{SUCCESS}", tags:)
    end

    ##
    # Records a failure metric for a controller action.
    # Includes error type in tags for error analysis.
    #
    # @param metric_base [String] Base metric name (e.g., APPOINTMENTS_CREATE)
    # @param error_type [String] Error type identifier
    # @param http_status [Integer, nil] Optional HTTP status (uses response.status if not provided)
    # @param additional_tags [Hash] Optional additional tags
    #
    # @example
    #   track_failure(APPOINTMENTS_CREATE, error_type: e.class.name)
    #   track_failure(APPOINTMENTS_CREATE, error_type: 'missing_session_data')
    #
    def track_failure(metric_base, error_type:, http_status: nil, additional_tags: {})
      status = http_status || (response.respond_to?(:status) ? response.status : nil)
      tags = build_metric_tags(
        http_status: status,
        error_type:,
        additional_tags:
      )

      StatsD.increment("#{metric_base}.#{FAILURE}", tags:)
    end

    ##
    # Records an infrastructure metric (rate limiting, session, Redis).
    # Uses a simpler tag set as these are not HTTP operations.
    #
    # @param metric_name [String] Full metric name
    # @param additional_tags [Hash] Optional additional tags
    #
    # @example
    #   track_infrastructure_metric(RATE_LIMIT_GENERATION_EXCEEDED)
    #   track_infrastructure_metric(SESSION_OTP_GENERATED, identifier: uuid)
    #
    def track_infrastructure_metric(metric_name, additional_tags: {})
      tags = [SERVICE_TAG]
      additional_tags.each { |key, value| tags << "#{key}:#{value}" }

      StatsD.increment(metric_name, tags:)
    end

    ##
    # Builds standardized metric tags for controller operations.
    #
    # @param http_status [Integer, nil] HTTP status code
    # @param error_type [String, nil] Error class name
    # @param additional_tags [Hash] Optional additional tags
    # @return [Array<String>] Array of formatted tags
    #
    def build_metric_tags(http_status: nil, error_type: nil, additional_tags: {})
      tags = [SERVICE_TAG]

      tags << "endpoint:#{action_name}" if respond_to?(:action_name) && action_name
      tags << "http_method:#{request.method}" if respond_to?(:request) && request.respond_to?(:method)
      tags << "http_status:#{http_status}" if http_status
      tags << "error_type:#{error_type}" if error_type

      additional_tags.each { |key, value| tags << "#{key}:#{value}" }

      tags
    end
  end
end
