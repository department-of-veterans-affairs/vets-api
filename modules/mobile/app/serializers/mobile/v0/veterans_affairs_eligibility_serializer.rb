# frozen_string_literal: true

require 'fast_jsonapi'

module Mobile
  module V0
    class VeteransAffairsEligibilitySerializer
      include FastJsonapi::ObjectSerializer

      set_type :va_eligibility
      attributes :services

      def initialize(id, services)
        resource = ServiceStruct.new(id, services)
        super(resource, {})
      end
    end

    ServiceStruct = Struct.new(:id, :services)
  end
end
