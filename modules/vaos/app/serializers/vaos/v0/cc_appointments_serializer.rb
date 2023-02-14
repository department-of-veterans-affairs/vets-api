# frozen_string_literal: true

# VAOS V0 routes and controllers no longer in use
# :nocov:
module VAOS
  module V0
    class CCAppointmentsSerializer
      include FastJsonapi::ObjectSerializer

      set_id :appointment_request_id
      set_type :cc_appointments

      attributes :appointment_request_id,
                 :distance_eligible_confirmed,
                 :name,
                 :provider_practice,
                 :provider_phone,
                 :address,
                 :instructions_to_veteran,
                 :appointment_time,
                 :time_zone
    end
  end
end
# :nocov:
