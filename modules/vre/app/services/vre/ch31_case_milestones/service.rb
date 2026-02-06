# frozen_string_literal: true

module VRE
  module Ch31CaseMilestones
    class Service < VRE::Service
      configuration VRE::Ch31CaseMilestones::Configuration

      class Ch31CaseMilestonesError < StandardError; end

      STATSD_KEY_PREFIX = 'api.res.case_milestones'
      SERVICE_UNAVAILABLE_ERROR = 'APNX-1-4187-000'

      def initialize(icn)
        super()
        raise Common::Exceptions::Forbidden, detail: 'ICN is required' if icn.blank?

        @icn = icn
      end

      # Updates Ch31 case milestones
      #
      # @param milestone_params [Hash] parameters containing milestones
      # @return [Hash]
      #
      def update_milestones(milestone_params)
        payload = build_payload(milestone_params)
        raw_response = send_to_res(payload: payload.to_json)
        VRE::Ch31CaseMilestones::Response.new(raw_response.status, raw_response)
      rescue Common::Exceptions::BackendServiceException => e
        log_error(e)
        raise e unless service_unavailable?(e)
      end

      private

      def api_path
        'update-ch3-milestone-status'
      end

      def build_payload(milestone_params)
        {
          icn: @icn,
          milestones: milestone_params[:milestones]
        }
      end

      def log_error(e)
        message = e.original_body['errorMessageList'] || e.original_body['error']
        Rails.logger.error("Failed to update Ch. 31 case milestones: #{message}",
                           backtrace: e.backtrace)
      end

      def service_unavailable?(e)
        return false unless e.original_body['error'] == SERVICE_UNAVAILABLE_ERROR

        raise e.class.new('RES_CH31_CASE_MILESTONES_503', e.response_values)
      end
    end
  end
end
