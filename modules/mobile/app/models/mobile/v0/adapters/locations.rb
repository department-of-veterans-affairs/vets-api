# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class Locations
        def parse(facility, id)
          Mobile::V0::Location.new(
            id:,
            name: facility['name'],
            address: Mobile::FacilitiesHelper.address_from_facility(facility),
            phone: Mobile::FacilitiesHelper.phone_from_facility(facility),
            lat: facility.lat,
            long: facility.long,
            url: nil,
            code: nil
          )
        end
      end
    end
  end
end
