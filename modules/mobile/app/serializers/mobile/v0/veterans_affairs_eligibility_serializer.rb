# frozen_string_literal: true

require 'fast_jsonapi'

module Mobile
  module V0
    class VeteransAffairsEligibilitySerializer
      include FastJsonapi::ObjectSerializer

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
