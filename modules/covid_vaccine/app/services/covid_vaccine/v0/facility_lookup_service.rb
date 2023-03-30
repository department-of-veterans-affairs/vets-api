# frozen_string_literal: true

require 'lighthouse/facilities/client'

module CovidVaccine
  module V0
    class FacilityLookupService
      # List of VA "consolidated" facilities, VAMCs that had their
      # VistA instances merged and therefore are VAMCs that may have a
      # longer than 3 digit station ID
      CONSOLIDATED_FACILITIES = %w[528 528A4 528A5 528A6 528A7 528A8
                                   549 589 589A4 589A5 589A6 589A7
                                   620 620A4 626 626A4 636 636A6
                                   636A8 657 657A4 657A5].freeze

      # return a map of attributes including the zipcodes lat/long
      # and the list of n closest health facilities
      def facilities_for(zipcode)
        zcta_row = ZCTA[zipcode&.[](0...5)]
        return {} if zcta_row.blank?

        lat = zcta_row[ZCTA_LAT_HEADER]
        lng = zcta_row[ZCTA_LON_HEADER]
        {
          zip_code: zipcode,
          zip_lat: lat,
          zip_lon: lng
        }.merge(nearest_facilities(lat, lng))
      end

      private

      ## Get the n nearest facility IDs to the provided latitude/longitude
      # Attempts to find n nearest by drive-time. If an insufficient number
      # of results is returned based on limitations of the drive-time API,
      # scraps those results and falls back to find the n nearest by distance
      #
      def nearest_facilities(lat, lng)
        client = Lighthouse::Facilities::Client.new
        response = client.nearby(lat:, lng:)
        # Work around a bug in /nearby API that returns non-VHA facilities
        response = response.filter { |x| x.id.start_with?('vha_') }
        result = nearest_vamc(response.map { |x| x.id.delete_prefix('vha_') })
        if result.blank?
          # Does not seem feasible that a location would be closer to
          # 30 clinics than any VAMCs
          response = client.get_facilities(lat:, long: lng,
                                           per_page: 30, type: 'health')
          result = nearest_vamc(response.map { |x| x.id.delete_prefix('vha_') })
        end
        sta3n = result.last if result.last.length == 3
        sta6a = result.first if result.first.length > 3
        sta6a = result.last if result.last.length > 3
        {
          sta3n:,
          sta6a:
        }
      rescue
        # For now just bail on any exception while getting facilities
        # TODO Add Sentry logging
        {}
      end

      ## Get the prefix of the provided list up to and including the nearest VAMC,
      # either a facility with a  sta3n (3-digit numeric) station ID,
      # or a facility from the consolidated facility list
      # Returns nil if the provided list does not contain any VAMC
      def nearest_vamc(facility_ids)
        idx = facility_ids.find_index { |f| f.length == 3 or CONSOLIDATED_FACILITIES.include?(f) }
        return nil if idx.nil?

        facility_ids[0..idx]
      end
    end
  end
end
