# frozen_string_literal: true

module Facilities
  class VHAFacility < BaseFacility
    FACILITY_TYPE = 'va_health_facility'
    default_scope { where(facility_type: FACILITY_TYPE) }
  end
end
