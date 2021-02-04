# frozen_string_literal: true

module FacilitiesQuery
  class ZipQuery < Base
    def run
      # TODO: allow user to set distance from zip
      zip_plus0 = params[:zip][0...5]
      requested_zip = ZCTA[zip_plus0]
      # TODO: iterate over zcta, pushing each zip code that is within distance into an array
      # TODO: change zip criteria to array of zip codes
      conditions = "address ->'physical'->>'zip' ilike '#{requested_zip&.[](0)}%'"
      BaseFacility::TYPES.flat_map do |facility_type|
        get_facility_data(conditions, params[:type], facility_type, params[:services])
      end
    end
  end
end
