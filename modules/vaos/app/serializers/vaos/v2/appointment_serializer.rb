# frozen_string_literal: true

module VAOS
  module V2
    class AppointmentSerializer
      include FastJsonapi::ObjectSerializer

      set_id :id

      set_type :appointment

      attributes :id,
                 :kind,
                 :status,
                 :service_type,
                 :patient_icn,
                 :location_id,
                 :clinic,
                 :telehealth,
                 :practitioners,
                 :reason,
                 :start,
                 :end,
                 :minutes_duration,
                 :slot,
                 :requested_periods,
                 :contact,
                 :preferred_times_for_phone_call,
                 :priority,
                 :cancellation_reason,
                 :description,
                 :comment
    end
  end
end
