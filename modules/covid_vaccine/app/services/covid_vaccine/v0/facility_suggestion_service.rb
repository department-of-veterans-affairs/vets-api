# frozen_string_literal: true

require 'lighthouse/facilities/client'
require 'sentry_logging'
require 'common/exceptions/bad_gateway'
require 'common/exceptions/unprocessable_entity'

module CovidVaccine
  module V0
    class FacilitySuggestionService
      include SentryLogging

      # List of VA "consolidated" facilities, VAMCs that had their
      # VistA instances merged and therefore are VAMCs that may have a
      # longer than 3 digit station ID
      CONSOLIDATED_FACILITIES = %w[528 528A4 528A5 528A6 528A7 528A8
                                   549 589 589A4 589A5 589A6 589A7
                                   620 620A4 626 626A4 636 636A6
                                   636A8 657 657A4 657A5].freeze

      # return a list of nearby facilities based on provided zipcode
      def facilities_for(zipcode, count = 3)
        zcta_row = ZCTA[zipcode&.[](0...5)]
        raise Common::Exceptions::UnprocessableEntity.new(detail: 'Invalid ZIP Code') if zcta_row.blank?

        lat = zcta_row[ZCTA_LAT_HEADER]
        lng = zcta_row[ZCTA_LON_HEADER]
        nearest_facilities(lat, lng, count)
      end

      private

      ## Get the n nearest facility IDs to the provided latitude/longitude
      # by as-the-crow-flies distance
      #
      def nearest_facilities(lat, lng, count)
        client = Lighthouse::Facilities::Client.new

        allowed_vamcs = proc do |f|
          id = f.id.delete_prefix('vha_')
          allowed_facilities.include?(id)
        end

        elements = proc do |f|
          { id: f.id,
            name: f.name,
            distance: f.distance,
            city: f.address.dig('physical', 'city'),
            state: f.address.dig('physical', 'state') }
        end

        # Get 50 nearest health facilities inclusive of clinics, etc, and
        # then filter down to VAMCs only.
        # There may not be the number of requested VAMCs in this list
        # if there are many clinics closer by, but return as many as are
        # available up to requested count.
        response = client.get_facilities(lat:, long: lng,
                                         per_page: 50, type: 'health')

        result = response.select(&allowed_vamcs).map(&elements)
        result.first(count)
      rescue => e
        # For now just log any exception while getting facilities and return an empty result
        log_exception_to_sentry(e)
        raise Common::Exceptions::BadGateway
      end

      def allowed_facilities
        @allowed_facilities ||= Settings.covid_vaccine.allowed_facilities.map(&:to_s)
      end
    end
  end
end
