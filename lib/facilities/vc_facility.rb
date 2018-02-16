# frozen_string_literal: true

module Facilities
  class VCFacility < BaseFacility
    FACILITY_TYPE = 'vet_center'
    default_scope { where(facility_type: FACILITY_TYPE) }
  end
end
