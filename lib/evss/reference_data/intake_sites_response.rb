# frozen_string_literal: true

require 'evss/response'

module EVSS
  module ReferenceData
    ##
    # Model for Intake Sites returned by reference_datea
    #
    # @param status [Integer] The HTTP status code
    # @param response [Hash] The API response
    #
    # @!attribute countries
    #   @return [Array[String]] An array of intake sites
    #
    class IntakeSitesResponse < EVSS::Response
      attribute :separation_locations, Array[Hash]

      def initialize(status, response = nil)
        separation_locations = response&.body&.dig('intake_sites')
        super(status, separation_locations:)
      end
    end
  end
end
