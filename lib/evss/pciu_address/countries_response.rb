# frozen_string_literal: true

require 'evss/response'

module EVSS
  module PCIUAddress
    ##
    # Model for countries returned by PCIU
    #
    # @param status [Integer] The HTTP status code
    # @param response [Hash] The API response
    #
    # @!attribute countries
    #   @return [Array[String]] An array of country names
    #
    class CountriesResponse < EVSS::Response
      attribute :countries, String, array: true, default: []

      def initialize(status, response = nil)
        countries = response&.body&.dig('cnp_countries') || response&.body&.dig('countries')
        super(status, countries:)
      end
    end
  end
end
