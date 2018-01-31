# frozen_string_literal: true
require 'evss/response'

module EVSS
  module AWS
    module ReferenceData
      class TreatmentCentersResponse < EVSS::Response
        attribute :treatment_centers, Array[EVSS::ReferenceData::TreatmentCenter]

        def initialize(status, response = nil)
        	# TODO : tell evss to rename facilities to treatment_centers
          super(status, treatment_centers: response&.body&.dig('facilities'))
        end
      end
    end
  end
end
