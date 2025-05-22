# frozen_string_literal: true

require 'evss/response'

module EVSS
  module PCIUAddress
    ##
    # Model for states returned by PCIU
    #
    # @param status [Integer] The HTTP status code
    # @param response [Hash] The API response
    #
    # @!attribute countries
    #   @return [Array[String]] An array of state names
    #
    class StatesResponse < EVSS::Response
      attribute :states, String, array: true, default: []

      def initialize(status, response = nil)
        states = response&.body&.dig('cnp_states') || response&.body&.dig('states')
        super(status, states:)
      end
    end
  end
end
