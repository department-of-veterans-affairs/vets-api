# frozen_string_literal: true

module Mobile
  module V0
    class AppointmentSerializer
      include JSONAPI::Serializer

      attributes :appointment_type,
                 :appointment_ien,
                 :cancel_id,
                 :comment,
                 :healthcare_provider,
                 :healthcare_service,
                 :location,
                 :physical_location,
                 :minutes_duration,
                 :phone_only,
                 :start_date_local,
                 :start_date_utc,
                 :status,
                 :status_detail,
                 :time_zone,
                 :vetext_id,
                 :reason,
                 :is_covid_vaccine,
                 :is_pending,
                 :proposed_times,
                 :type_of_care,
                 :patient_phone_number,
                 :patient_email,
                 :best_time_to_call,
                 :friendly_location_name,
                 :service_category_name,
                 :travelPayClaim
    end
  end
end
