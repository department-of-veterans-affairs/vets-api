# frozen_string_literal: true

require 'facilities/shared_client'

module Facilities
  class VBAFacility < BaseFacility
    FACILITY_TYPE = 'va_benefits_facility'
    default_scope { where(facility_type: FACILITY_TYPE) }

    class << self
      def pull_source_data
        SharedClient.new.get_all_vba.map(&method(:new))
      end
    end
  end
end
