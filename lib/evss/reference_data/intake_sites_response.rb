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
      attribute :intake_sites, Array[Hash]

      def initialize(status, response = nil)
        intake_sites = response&.body&.dig('intake_sites')
        super(status, intake_sites: intake_sites)
      end
    end
  end
end
