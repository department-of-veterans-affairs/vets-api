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
      attribute :rated_disabilities, EVSS::DisabilityCompensationForm::RatedDisability, array: true, default: []

      def initialize(status, response = nil)
        super(status, response.body) if response
      end
    end
  end
end
