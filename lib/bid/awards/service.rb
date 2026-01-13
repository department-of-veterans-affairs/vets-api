# frozen_string_literal: true

require 'bid/awards/configuration'
require 'bid/service'
require 'common/client/base'

module BID
  module Awards
    class Service < BID::Service
      configuration BID::Awards::Configuration
      STATSD_KEY_PREFIX = 'api.bid.awards'

      def get_awards_pension
        with_monitoring do
          perform(
            :get,
            end_point,
            nil,
            request_headers
          )
        end
      end

      # This method will retrieve a list of current award events for the user
      # Mock response can be found: spec/lib/bid/awards/responses/current_awards_response.json
      def get_current_awards
        with_monitoring do
          perform(
            :get,
            current_awards_endpoint,
            nil,
            request_headers
          )
        end
      end

      private

      def request_headers
        config.request_headers
      end

      def participant_id
        @user.participant_id
      end

      def current_awards_endpoint
        # NOTE: participant_id is the same as vereranId and beneficiaryId
        # awardTC = CPL (compensation pension live)
        "#{config.base_path}current/#{participant_id}/beneficiaryId/#{participant_id}?awardTC=CPL"
      end

      def end_point
        "#{config.base_path}pension/#{participant_id}"
      end
    end
  end
end
