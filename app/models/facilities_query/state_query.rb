# frozen_string_literal: true

module FacilitiesQuery
  class StateQuery < Base
    def run
      state = params[:state]
      conditions = "address -> 'physical' ->> 'state' ilike '#{state}'"
      BaseFacility::TYPES.flat_map do |facility_type|
        get_facility_data(conditions, params[:type], facility_type, params[:services])
      end
    end
  end
end
