# frozen_string_literal: true

module VRE
  module Ch31Eligibility
    class Service < VRE::Service
      configuration VRE::Ch31Eligibility::Configuration

      class Ch31EligibilityError < StandardError; end

      STATSD_KEY_PREFIX = 'api.res.eligibility'
      SERVICE_UNAVAILABLE_ERROR = 'APNX-1-4187-000'

      def initialize(icn)
        super()
        raise Common::Exceptions::ParameterMissing, 'ICN' if icn.blank?

        @icn = icn
      end

      # Requests current user's Ch31 eligibility status and details
      #
      # @return [Hash]
      #
      def get_details
        raw_response = send_to_res(payload: { icn: @icn }.to_json)
        VRE::Ch31Eligibility::Response.new(raw_response.status, raw_response)
      rescue Common::Exceptions::BackendServiceException => e
        log_error(e)
        raise e unless service_unavailable?(e)
      end

      private

      def api_path
        'chapter31-eligibility-details-search'
      end

      def log_error(e)
        message = e.original_body['errorMessageList'] || e.original_body['error']
        Rails.logger.error("Failed to retrieve Ch. 31 eligibility details: #{message}",
                           backtrace: e.backtrace)
      end

      def service_unavailable?(e)
        return false unless e.original_body['error'] == SERVICE_UNAVAILABLE_ERROR

        raise e.class.new('RES_CH31_ELIGIBILITY_503', e.response_values)
      end
    end
  end
end
