# frozen_string_literal: true

module Facilities
  class VHAFacility < BaseFacility
    FACILITY_TYPE = 'va_health_facility'
    default_scope { where(facility_type: FACILITY_TYPE) }

    class << self
      def pull_source_data
        Facilities::SharedClient.new.get_all_vha.map(&method(:new))
      end
    end
  end
end
