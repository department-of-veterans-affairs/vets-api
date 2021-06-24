# frozen_string_literal: true

require 'fast_jsonapi'

module VAOS
  module V2
    class PatientAppointmentMetadataSerializer
      include FastJsonapi::ObjectSerializer

      attributes :has_required_appointment_history,
                 :is_eligible_for_new_appointment_request
    end
  end
end
