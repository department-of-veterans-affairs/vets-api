# frozen_string_literal: true

require 'bid/awards/configuration'
require 'bid/service'
require 'common/client/base'

# module for BID service
module BID
  # Awards module containing configuration and service classes for BID Awards functionality
  module Awards
    # Service class for interacting with BID Awards API
    # Handles pension award data retrieval for veterans
    class Service < BID::Service
      configuration BID::Awards::Configuration

      # StatsD key prefix for metrics tracking
      STATSD_KEY_PREFIX = 'api.bid.awards'

      # Retrieves pension awards information for the current user
      # @return [Faraday::Response] the HTTP response containing pension award data
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

      # Constructs the authorization headers for API requests
      # @return [Hash] headers hash with Bearer token authorization
      def request_headers
        {
          Authorization: "Bearer #{Settings.bid.awards.credentials}"
        }
      end

      # Constructs the API endpoint URL for pension awards
      # @return [String] the full URL endpoint for pension awards API
      def end_point
        "#{Settings.bid.awards.base_url}/api/v1/awards/pension/#{@user.participant_id}"
      end
    end
  end
end
