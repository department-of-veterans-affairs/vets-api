# frozen_string_literal: true

require 'facilities/shared_client'

module Facilities
  class VCFacility < BaseFacility
    FACILITY_TYPE = 'vet_center'
    default_scope { where(facility_type: FACILITY_TYPE) }

    class << self
      def pull_source_data
        SharedClient.new.get_all_vc.map(&method(:new))
      end
    end
  end
end
