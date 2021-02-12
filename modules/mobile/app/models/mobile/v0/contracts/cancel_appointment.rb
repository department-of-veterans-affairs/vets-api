# frozen_string_literal: true

module Mobile
  module V0
    module Contracts
      class CancelAppointment < Base
        params do
          required(:appointmentTime).filled(:date_time)
          required(:clinicId).filled(:string)
          required(:facilityId).filled(:string)
          required(:healthcareService).filled(:string)
        end

        def self.encode_cancel_id(start_date_local:, clinic_id:, facility_id:, healthcare_service:)
          appointment_time = Base64.encode64(start_date_local.strftime('%Y%m%d%H%S%M'))
          clinic_id = Base64.encode64(clinic_id)
          facility_id = Base64.encode64(facility_id)
          healthcare_service = Base64.encode64(healthcare_service)

          "#{appointment_time}-#{clinic_id}-#{facility_id}-#{healthcare_service}"
        end

        def self.decode_cancel_id(cancel_id)
          time_encoded, clinic_encoded, facility_encoded, healthcare_encoded = cancel_id.split('-')

          {
            appointmentTime: DateTime.strptime(Base64.decode64(time_encoded), '%Y%m%d%H%S%M'),
            clinicId: Base64.decode64(clinic_encoded),
            facilityId: Base64.decode64(facility_encoded),
            healthcareService: Base64.decode64(healthcare_encoded)
          }
        rescue ArgumentError
          raise Mobile::V0::Exceptions::ValidationErrors, OpenStruct.new(
            { errors: { appointmentTime: 'invalid date' } }
          )
        end
      end
    end
  end
end
