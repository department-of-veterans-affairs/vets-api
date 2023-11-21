# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class FacilityInfo
        def parse(facility:, user:, sort: nil, lat: nil, long: nil)
          Mobile::V0::FacilityInfo.new(
            id: facility.id,
            name: facility[:name],
            city: facility[:physical_address][:city],
            state: facility[:physical_address][:state],
            cerner: user.cerner_facility_ids.include?(facility.id),
            miles: distance(facility, user, sort, lat, long)
          )
        end

        private

        def distance(facility, user, sort, lat, long)
          if (location = user_location(user, sort, lat, long))
            Mobile::FacilitiesHelper.haversine_distance(location, [facility.lat, facility.long]).to_s
          end
        end

        def user_location(user, sort, lat, long)
          case sort
          when 'current'
            current_coords(lat, long)
          when 'home'
            home_coords(user)
          end
        end

        def current_coords(lat, long)
          [lat.to_f, long.to_f]
        end

        def home_coords(user)
          Mobile::FacilitiesHelper.user_address_coordinates(user)
        end
      end
    end
  end
end
