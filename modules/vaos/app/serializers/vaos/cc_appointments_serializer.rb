# frozen_string_literal: true

module VAOS
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
