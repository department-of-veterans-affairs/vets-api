# frozen_string_literal: true

require 'jsonapi/serializer'

module Mobile
  module V0
    class FacilityEligibilitySerializer
      include JSONAPI::Serializer

      set_type :FacilityEligibility
      attributes :facility_id, :eligible, :reason

      def initialize(facility_eligibilities, page_meta_data)
        resource = facility_eligibilities.collect do |facility_eligibility|
          FacilityEligibilityStruct.new(
            facility_eligibility.facility_id,
            facility_eligibility.facility_id,
            facility_eligibility.eligible,
            facility_eligibility.dig('ineligibility_reasons', 0, :coding, 0, :display)
          )
        end

        super(resource, page_meta_data)
      end
    end

    FacilityEligibilityStruct = Struct.new(:id, :facility_id, :eligible, :reason)
  end
end
