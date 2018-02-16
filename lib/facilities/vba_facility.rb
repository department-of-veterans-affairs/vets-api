# frozen_string_literal: true

module Facilities
  class VBAFacility < BaseFacility
    FACILITY_TYPE = 'va_benefits_facility'
    default_scope { where(facility_type: FACILITY_TYPE) }
  end
end
