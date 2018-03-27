# frozen_string_literal: true

require 'evss/response'
require 'evss/disability_compensation_form/rated_disabilities'

module EVSS
  module DisabilityCompensationForm
    class RatedDisabilitiesResponse < EVSS::Response
      attribute :rated_disabilities, Array[EVSS::DisabilityCompensationForm::RatedDisability]

      def initialize(status, response = nil)
        if response
          super(status, response.body)
        end
      end
    end
  end
end
