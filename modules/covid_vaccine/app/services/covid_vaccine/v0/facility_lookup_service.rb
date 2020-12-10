# frozen_string_literal: true

require 'lighthouse/facilities/client'

module CovidVaccine
  module V0
    class FacilityLookupService
      # return a map of attributes including the zipcodes lat/long
      # and the list of n closest health facilities
      def facilities_for(zipcode, count = 5)
        zcta_row = ZCTA[zipcode[0...5]]
        return { zip: nil } if zcta_row.blank?

        lat = zcta_row[ZCTA_LAT_HEADER]
        lng = zcta_row[ZCTA_LON_HEADER]
        {
          zip: zipcode,
          zip_lat: lat,
          zip_lng: lng,
          zip_facilities: nearest_facilities(lat, lng, count)
        }
      end

      private

      ## Get the n nearest facility IDs to the provided latitude/longitude
      # Attempts to find n nearest by drive-time. If an insufficient number
      # of results is returned based on limitations of the drive-time API,
      # scraps those results and falls back to find the n nearest by distance
      #
      def nearest_facilities(lat, lng, count)
        client = Lighthouse::Facilities::Client.new
        result = client.nearby(lat: lat, lng: lng)
        if result.length >= count
          result.map { |x| x.id.delete_prefix('vha_') }[0..count - 1]
        else
          result = client.get_facilities(lat: lat, long: lng, per_page: count, type: 'health')
          result.map { |x| x.id.delete_prefix('vha_') }
        end
      end
    end
  end
end
