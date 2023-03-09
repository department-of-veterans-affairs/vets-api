# frozen_string_literal: true

require 'jsonapi/serializer'

module VAOS
  module V2
    class CCEligibilitySerializer
      include JSONAPI::Serializer

      set_id do |object|
        object.patient_request[:service_type]
      end

      set_type :cc_eligibility

      attributes :eligible
    end
  end
end
