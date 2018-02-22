# frozen_string_literal: true

module Facilities
  class NCAFacility < BaseFacility
    FACILITY_TYPE = 'va_cemetery'
    default_scope { where(facility_type: FACILITY_TYPE) }

    class << self
      def pull_source_data
        Facilities::SharedClient.new.get_all_nca.map(&method(:new))
      end
    end
  end
end
