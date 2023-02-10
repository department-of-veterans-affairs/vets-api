# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class FacilityInfo
        def parse(facility, user, params)
          user_location = params[:sort] == 'current' ? current_coords(params) : home_coords(user)

          facility_parse(facility, user, user_location)
        end

        private

        def facility_parse(facility, user, user_location)
          Mobile::V0::FacilityInfo.new(
            id: facility.id,
            name: facility[:name],
            city: facility[:physical_address][:city],
            state: facility[:physical_address][:state],
            cerner: user.cerner_facility_ids.include?(facility.id),
            miles: Mobile::FacilitiesHelper.haversine_distance(user_location, [facility.lat, facility.long]).to_s
          )
        end

        def current_coords(params)
          params.require(:lat)
          params.require(:long)
          [params[:lat].to_f, params[:long].to_f]
        end

        def home_coords(user)
          Mobile::FacilitiesHelper.user_address_coordinates(user)
        end
      end
    end
  end
end
