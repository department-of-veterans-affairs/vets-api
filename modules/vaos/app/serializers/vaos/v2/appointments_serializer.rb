# frozen_string_literal: true

# VAOS V2 serializer not in use
# :nocov:
module VAOS
  module V2
    class AppointmentsSerializer
      include JSONAPI::Serializer

      set_id :id

      set_type :appointments

      attributes :id,
                 :kind,
                 :status,
                 :service_type,
                 :location_id,
                 :clinic,
                 :telehealth,
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
                 :comment,
                 :preferred_language,
                 :practitioner_ids
    end
  end
end
# :nocov:
