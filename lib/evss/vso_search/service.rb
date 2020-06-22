# frozen_string_literal: true

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
      def get_current_info(addtional_headers = {})
        with_monitoring_and_error_handling do
          perform(:post, 'getCurrentInfo', '', request_headers(addtional_headers)).body
        end
      end

      private

      def request_headers(additional_headers)
        {
          'ssn' => @user.ssn,
          'Authorization' => "Token token=#{Settings.caseflow.app_token}",
          'Content-Type' => 'application/json'
        }.merge(additional_headers)
      end
    end
  end
end
