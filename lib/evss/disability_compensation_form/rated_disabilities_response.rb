# frozen_string_literal: true

require 'evss/response'
require_relative 'rated_disability'

module EVSS
  module DisabilityCompensationForm
    # Model that contains an array of a veteran's parsed rated disabilities
    #
    # @!attribute rated_disabilities
    #   @return [Array<EVSS::DisabilityCompensationForm::RatedDisability>] The list of rated disabilities
    #
    class RatedDisabilitiesResponse < EVSS::Response
      attribute :rated_disabilities, Array[EVSS::DisabilityCompensationForm::RatedDisability]

      def initialize(status, response = nil)
        # This is temporary until EVSS::Response is converted to Vets::Response
        response.body['rated_disabilities'].map! do |rated_disability_response|
          EVSS::DisabilityCompensationForm::RatedDisability.new(rated_disability_response)
        end

        super(status, response.body) if response
      end
    end
  end
end
