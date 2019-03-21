# frozen_string_literal: true

require 'evss/response'
require 'evss/disability_compensation_form/rated_disabilities'

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
        super(status, response.body) if response
      end
    end
  end
end
