# frozen_string_literal: true

require 'common/exceptions'
require 'common/client/errors'
require 'json'

module VAOS
  module V2
    class PatientsService < VAOS::SessionService
      def get_patient_appointment_metadata(clinic_service_id, facility_id, type)
        with_monitoring do
          response = if Flipper.enabled?(:va_online_scheduling_use_vpg) &&
                        Flipper.enabled?(:va_online_scheduling_enable_OH_eligibility)
                       get_patient_appointment_metadata_vpg(clinic_service_id, facility_id, type)
                     else
                       get_patient_appointment_metadata_vaos(clinic_service_id, facility_id, type)
                     end

          OpenStruct.new(response.body.merge(id: SecureRandom.hex(2)))
        end
      end

      private

      def get_patient_appointment_metadata_vaos(clinic_service_id, facility_id, type)
        params = {
          clinicalServiceId: clinic_service_id,
          facilityId: facility_id,
          type:
        }

        perform(:get, "/vaos/v1/patients/#{user.icn}/eligibility", params, headers)
      end

      def get_patient_appointment_metadata_vpg(clinic_service_id, facility_id, type)
        params = {
          clinicalService: clinic_service_id,
          location: facility_id,
          type:
        }

        perform(:get, "/vpg/v1/patients/#{user.icn}/eligibility", params, headers)
      end
    end
  end
end
