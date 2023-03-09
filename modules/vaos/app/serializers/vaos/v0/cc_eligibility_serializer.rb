# frozen_string_literal: true

# VAOS V0 routes and controllers no longer in use
# :nocov:
require 'jsonapi/serializer'

module VAOS
  module V0
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
# :nocov:
