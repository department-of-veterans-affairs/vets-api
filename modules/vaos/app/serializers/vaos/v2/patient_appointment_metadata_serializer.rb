# frozen_string_literal: true

# VAOS V2 serializer not in use:
# :nocov:
require 'jsonapi/serializer'

module VAOS
  module V2
    class PatientAppointmentMetadataSerializer
      include JSONAPI::Serializer

      attributes :has_required_appointment_history,
                 :is_eligible_for_new_appointment_request
    end
  end
end
# :nocov:
