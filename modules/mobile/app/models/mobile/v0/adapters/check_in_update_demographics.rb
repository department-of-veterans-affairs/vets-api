# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class CheckInUpdateDemographics
        def parse(demographics)
          json = JSON.parse(demographics.body, symbolize_names: true)[:data][:attributes]

          Mobile::V0::CheckIn::UpdateDemographics.new(
            {
              id: json[:id],
              contactNeedsUpdate: json[:demographicsNeedsUpdate],
              emergencyContactNeedsUpdate: json[:emergencyContactNeedsUpdate],
              nextOfKinNeedsUpdate: json[:nextOfKinNeedsUpdate]
            }
          )
        end
      end
    end
  end
end
