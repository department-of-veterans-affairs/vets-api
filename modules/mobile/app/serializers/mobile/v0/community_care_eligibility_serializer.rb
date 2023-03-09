# frozen_string_literal: true

require 'jsonapi/serializer'

module Mobile
  module V0
    class CommunityCareEligibilitySerializer
      include JSONAPI::Serializer

      set_id do |object|
        object.patient_request[:service_type]
      end

      set_type :community_care_eligibility

      attributes :eligible
    end
  end
end
