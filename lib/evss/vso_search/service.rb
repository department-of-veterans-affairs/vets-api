# frozen_string_literal: true

require 'evss/service'
require 'evss/vso_search/configuration'

module EVSS
  module VSOSearch
    ##
    # Proxy Service for VSO search
    #
    # @example Create a service and fetching current info for a user
    #   vso_search_response = VSOSearch::Service.new.get_current_info
    #
    class Service < EVSS::Service
      configuration EVSS::VSOSearch::Configuration

      ##
      # Returns current info for a user by their SSN
      #
      # @param additional_headers [Hash] Any additional HTTP headers you want to include in the request.
      # @return [Faraday::Response] Faraday response instance
      #
      def get_current_info(additional_headers = {})
        with_monitoring_and_error_handling do
          perform(:post, 'getCurrentInfo', '', request_headers(additional_headers)).body
        end
      end

      private

      def request_headers(additional_headers)
        edipi = additional_headers['va_eauth_dodedipnid'].presence || @user&.edipi
        ssn = additional_headers['va_eauth_pnid'].presence || @user&.ssn
        {
          'ssn' => ssn,
          'edipi' => edipi,
          'Authorization' => "Token token=#{Settings.caseflow.app_token}",
          'Content-Type' => 'application/json'
        }.merge(additional_headers)
      end
    end
  end
end
