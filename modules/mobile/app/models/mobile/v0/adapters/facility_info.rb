# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class FacilityInfo
        def initialize(user)
          @current_user = user
        end

        def parse(facilities:, sort: nil, lat: nil, long: nil)
          adapted_facilities = facilities&.map do |facility|
            {
              id: facility.id,
              name: facility[:name],
              city: facility[:physical_address][:city],
              state: facility[:physical_address][:state],
              cerner: @current_user.cerner_facility_ids.include?(facility.id),
              miles: distance(facility, sort, lat, long)
            }
          end

          sorted_facilities = sort(adapted_facilities, sort)

          Mobile::V0::FacilityInfo.new(
            id: @current_user.uuid,
            facilities: sorted_facilities
          )
        end

        private

        def distance(facility, sort, lat, long)
          if (location = user_location(sort, lat, long))
            Mobile::FacilitiesHelper.haversine_distance(location, [facility.lat, facility.long]).to_s
          end
        end

        def user_location(sort, lat, long)
          case sort
          when 'current'
            current_coords(lat, long)
          when 'home'
            home_coords
          end
        end

        def current_coords(lat, long)
          [lat.to_f, long.to_f]
        end

        def home_coords
          Mobile::FacilitiesHelper.user_address_coordinates(@current_user)
        end

        def sort(facilities, sort_method)
          case sort_method
          when 'home', 'current'
            facilities.sort_by { |facility| facility[:miles].to_f }
          when 'alphabetical'
            sort_by_name(facilities)
          else
            facilities
          end
        end

        def sort_by_name(facilities)
          facilities.sort_by { |facility| facility[:name] }
        end
      end
    end
  end
end
