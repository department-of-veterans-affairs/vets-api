# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class RatedDisabilitiesResponse < EVSS::Response
      attribute :rated_disabilities, Array[EVSS::DisabilityCompensationForm::RatedDisability]

      def initialize(status, response = nil)
        super(status, response.body) if response
      end
    end
  end
end
