# frozen_string_literal: true

require 'jsonapi/serializer'

module Mobile
  module V0
    class VeteransAffairsEligibilitySerializer
      include JSONAPI::Serializer

      set_type :va_eligibility
      attributes :services, :cc_supported

      def initialize(id, services, cc_supported)
        resource = ServiceStruct.new(id, services, cc_supported)
        super(resource, {})
      end
    end

    ServiceStruct = Struct.new(:id, :services, :cc_supported)
  end
end
