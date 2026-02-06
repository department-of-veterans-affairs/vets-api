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

      # This method will retrieve a list of current award events for the user
      # Mock response is defined in: spec/lib/bid/awards/support/current_awards_response.rb (RSpec shared context)
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

      # Constructs the authorization headers for API requests
      # @return [Hash] headers hash with Bearer token authorization
      def request_headers
        config.request_headers
      end

      def participant_id
        @user.participant_id.presence || raise(StandardError,
                                               'BID Awards Service requires a participant_id for the user')
      end

      def current_awards_endpoint
        # NOTE: participant_id is the same as vereranId and beneficiaryId
        # awardTC = CPL (compensation pension live)
        "#{config.base_path}current/#{participant_id}/beneficiaryId/#{participant_id}?awardTC=CPL"
      end

      # Constructs the API endpoint URL for pension awards
      # @return [String] the full URL endpoint for pension awards API
      def end_point
        "#{config.base_path}pension/#{participant_id}"
      end
    end
  end
end
