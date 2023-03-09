# frozen_string_literal: true

module Mobile
  module V0
    class FacilitiesInfoSerializer
      include JSONAPI::Serializer

      set_type :facilities_info
      attributes :facilities

      def initialize(id, facilities)
        resource = FacilityInfoStruct.new(id, facilities)
        super(resource, {})
      end
    end

    FacilityInfoStruct = Struct.new(:id, :facilities)
  end
end
