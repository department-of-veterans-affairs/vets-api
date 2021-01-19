# frozen_string_literal: true

module Mobile
  module V0
    class AppointmentSerializer
      include FastJsonapi::ObjectSerializer

      attributes :appointment_type,
                 :comment,
                 :facility_id,
                 :healthcare_service,
                 :location,
                 :minutes_duration,
                 :start_date_local,
                 :start_date_utc,
                 :status
    end
  end
end
