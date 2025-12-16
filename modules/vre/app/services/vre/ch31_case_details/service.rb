# frozen_string_literal: true

module VRE
  module Ch31CaseDetails
    class Service < VRE::Service
      configuration VRE::Ch31CaseDetails::Configuration

      class Ch31CaseDetailsError < StandardError; end

      STATSD_KEY_PREFIX = 'api.res.case_details'
      SERVICE_UNAVAILABLE_ERROR = 'APNX-1-4187-000'

      def initialize(icn)
        super()
        raise Common::Exceptions::ParameterMissing, 'ICN' if icn.blank?

        @icn = icn
      end

      # Requests current user's Ch31 case details
      #
      # @return [Hash]
      #
      def get_details
        raw_response = send_to_res(payload: { icn: @icn }.to_json)
        VRE::Ch31CaseDetails::Response.new(raw_response.status, raw_response)
      rescue Common::Exceptions::BackendServiceException => e
        log_error(e)
        raise e unless service_unavailable?(e)
      end

      private

      def api_path
        'get-ch31-case-details'
      end

      def log_error(e)
        message = e.original_body['errorMessageList'] || e.original_body['error']
        Rails.logger.error("Failed to retrieve Ch. 31 case details: #{message}",
                           backtrace: e.backtrace)
      end

      def service_unavailable?(e)
        return false unless e.original_body['error'] == SERVICE_UNAVAILABLE_ERROR

        raise e.class.new('RES_CH31_CASE_DETAILS_503', e.response_values)
      end
    end
  end
end
