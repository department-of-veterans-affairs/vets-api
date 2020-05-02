# frozen_string_literal: true

require 'fast_jsonapi'

module VAOS
  module V0
    class CCEligibilitySerializer
      include FastJsonapi::ObjectSerializer

      set_id do |object|
        object.patient_request[:service_type]
      end

      set_type :cc_eligibility

      attributes :eligible
    end
  end
end
