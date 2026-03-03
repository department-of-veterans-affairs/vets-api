# frozen_string_literal: true

module VRE
  module Ch31CaseMilestones
    class Service < VRE::Service
      configuration VRE::Ch31CaseMilestones::Configuration

      STATSD_KEY_PREFIX = 'api.res.case_milestones'

      def initialize(icn)
        super()
        raise Common::Exceptions::ParameterMissing, 'ICN' if icn.blank?

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
        raise e
      end

      private

      def api_path
        'update-ch31-milestone-status'
      end

      def request_headers
        {
          'Appian-API-Key' => Settings.res.api_key.to_s
        }
      end

      def build_payload(milestone_params)
        {
          icn: @icn,
          milestones: milestone_params.to_unsafe_h[:milestones]
        }
      end

      def log_error(e)
        message = e.original_body&.[]('errorMessageList') || e.original_body&.[]('error') || 'Unknown error'
        Rails.logger.error("Failed to update Ch. 31 case milestones: #{message}",
                           backtrace: e.backtrace)
      end
    end
  end
end
