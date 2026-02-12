# frozen_string_literal: true

require 'common/client/base'
require 'common/exceptions/upstream_partial_failure'
require_relative 'configuration'
require_relative 'operation_outcome_detector'

module UnifiedHealthData
  class Client < Common::Client::Base
    STATSD_KEY_PREFIX = 'api.uhd'
    include Common::Client::Concerns::Monitoring

    configuration UnifiedHealthData::Configuration

    def get_allergies_by_date(patient_id:, start_date:, end_date:)
      path = "#{config.base_path}allergies?patientId=#{patient_id}&startDate=#{start_date}&endDate=#{end_date}"
      perform(:get, path, nil, request_headers)
    end

    def get_labs_by_date(patient_id:, start_date:, end_date:)
      path = "#{config.base_path}labs?patientId=#{patient_id}&startDate=#{start_date}&endDate=#{end_date}"
      perform(:get, path, nil, request_headers)
    end

    def get_conditions_by_date(patient_id:, start_date:, end_date:)
      path = "#{config.base_path}conditions?patientId=#{patient_id}&startDate=#{start_date}&endDate=#{end_date}"
      perform(:get, path, nil, request_headers)
    end

    def get_notes_by_date(patient_id:, start_date:, end_date:)
      path = "#{config.base_path}notes?patientId=#{patient_id}&startDate=#{start_date}&endDate=#{end_date}"
      perform(:get, path, nil, request_headers)
    end

    def get_vitals_by_date(patient_id:, start_date:, end_date:)
      path = "#{config.base_path}vitals?patientId=#{patient_id}&startDate=#{start_date}&endDate=#{end_date}"
      perform(:get, path, nil, request_headers)
    end

    def get_immunizations_by_date(patient_id:, start_date:, end_date:)
      path = "#{config.base_path}immunizations?patientId=#{patient_id}&startDate=#{start_date}&endDate=#{end_date}"
      perform(:get, path, nil, request_headers)
    end

    def get_prescriptions_by_date(patient_id:, start_date:, end_date:)
      path = "#{config.base_path}medications?patientId=#{patient_id}&startDate=#{start_date}&endDate=#{end_date}"
      perform(:get, path, nil, request_headers)
    end

    def refill_prescription_orders(request_body)
      path = "#{config.base_path}medications/rx/refill"
      perform(:post, path, request_body.to_json, request_headers(include_content_type: true))
    end

    def get_avs(patient_id:, appt_id:)
      path = "#{config.base_path}appointments/#{appt_id}/avs?patientId=#{patient_id}"
      perform(:get, path, nil, request_headers)
    end

    def get_ccd(patient_id:, start_date:, end_date:)
      path = "#{config.base_path}ccd/oracle-health"
      params = { patientId: patient_id, startDate: start_date, endDate: end_date }
      perform(:get, path, params, request_headers)
    end

    private

    # Override perform to automatically detect OperationOutcome partial failures in FHIR responses.
    # This ensures all SCDF API calls are checked without requiring manual calls at each endpoint.
    #
    # @param method [Symbol] HTTP method (:get, :post, etc.)
    # @param path [String] API path
    # @param params [Hash, nil] Request parameters or body
    # @param headers [Hash, nil] Request headers
    # @return [Faraday::Response] The response from the API
    # @raise [Common::Exceptions::UpstreamPartialFailure] when OperationOutcome errors detected
    def perform(method, path, params = nil, headers = nil)
      response = super
      check_for_partial_failures!(response, path)
      response
    end

    # Checks the response body for OperationOutcome resources with error severity.
    # The detector handles any response format gracefully - non-SCDF responses
    # (arrays, different hash structures) will simply return partial_failure? = false.
    #
    # @param response [Faraday::Response] The response from the API
    # @param path [String] The API path for logging/metrics
    # @raise [Common::Exceptions::UpstreamPartialFailure] when partial failures detected
    def check_for_partial_failures!(response, path)
      detector = OperationOutcomeDetector.new(response.body)
      return unless detector.partial_failure?

      resource_type = extract_resource_type(path)
      detector.log_and_track(resource_type:)

      raise Common::Exceptions::UpstreamPartialFailure.new(
        failed_sources: detector.failed_sources,
        failure_details: detector.failure_details
      )
    end

    # Extracts the resource type from the API path for logging and metrics
    # @param path [String] The API path (e.g., "/uhd/v1/allergies?patientId=...")
    # @return [String] The resource type (e.g., "allergies")
    def extract_resource_type(path)
      # Extract resource type from path like "/uhd/v1/allergies?..." or "/uhd/v1/ccd/oracle-health"
      path_without_query = path.split('?').first
      segments = path_without_query.split('/')
      # Find the segment after the version (e.g., "v1")
      version_index = segments.index { |s| s.match?(/^v\d+$/) }
      return 'unknown' unless version_index

      segments[version_index + 1] || 'unknown'
    end

    def fetch_access_token
      with_monitoring do
        response = connection.post(config.token_path) do |req|
          req.headers['Content-Type'] = 'application/json'
          req.body = {
            appId: config.app_id,
            appToken: config.app_token,
            subject: config.subject,
            userType: config.user_type
          }.to_json
        end
        response.headers['authorization']
      end
    end

    def request_headers(include_content_type: false)
      headers = {
        'Authorization' => fetch_access_token,
        'x-api-key' => config.x_api_key
      }
      headers['Content-Type'] = 'application/json' if include_content_type
      headers
    end
  end
end
