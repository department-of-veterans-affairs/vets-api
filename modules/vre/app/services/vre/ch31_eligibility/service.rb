# frozen_string_literal: true

module VRE
  module Ch31Eligibility
    class Service < VRE::Service
      configuration VRE::Ch31Eligibility::Configuration

      # TO-DO: coordinate not found error with RES
      RES_NOT_FOUND_STATUS = 500
      ERRORS_KEY = 'errorMessageList'
      NOT_FOUND_MESSAGE = 'Internal server error occurred while retrieving data from MPI'

      class Ch31EligibilityError < StandardError; end

      STATSD_KEY_PREFIX = 'api.res.eligibility'

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
        if record_not_found?(e)
          raise e.class.new('RES_CH31_ELIGIBILITY_404', e.response_values)
        else
          raise e
        end
      end

      private

      def api_path
        'chapter31-eligibility-details-search'
      end

      def record_not_found?(e)
        e.original_status == RES_NOT_FOUND_STATUS &&
        e.original_body[ERRORS_KEY]&.any? { |err| err.include?(NOT_FOUND_MESSAGE)}
      end

      def log_error(e)
        Rails.logger.error(e)
        Rails.logger.error({ messages: e.original_body[ERRORS_KEY] })
      end
    end
  end
end
