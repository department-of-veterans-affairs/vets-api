# frozen_string_literal: true

module Mobile
  module V0
    class AppointmentSerializer
      include FastJsonapi::ObjectSerializer

      attributes :appointment_type,
                 :cancel_id,
                 :comment,
                 :healthcare_service,
                 :location,
                 :minutes_duration,
                 :start_date_local,
                 :start_date_utc,
                 :status,
                 :status_detail,
                 :time_zone,
                 :vetext_id
    end
  end
end
