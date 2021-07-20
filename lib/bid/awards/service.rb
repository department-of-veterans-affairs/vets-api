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

      private

      def request_headers
        {
          Authorization: "Bearer #{Settings.bid.awards.credentials}"
        }
      end

      def end_point
        "#{Settings.bid.awards.base_url}/api/v1/awards/pension/#{@user.participant_id}"
      end
    end
  end
end
