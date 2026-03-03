# frozen_string_literal: true

require 'common/exceptions'
require 'common/client/errors'
require 'json'

module VAOS
  module V2
    class PatientsService < VAOS::SessionService
      def get_patient_appointment_metadata(clinic_service_id, facility_id, type)
        with_monitoring do
          response = if Flipper.enabled?(:va_online_scheduling_use_vpg, user)
                       get_patient_appointment_metadata_vpg(clinic_service_id, facility_id, type)
                     else
                       get_patient_appointment_metadata_vaos(clinic_service_id, facility_id, type)
                     end
          if Flipper.enabled?(:va_online_scheduling_backend_oh_migration_check, user)
            check_migrations(response.body, facility_id, type)
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

        with_monitoring do
          perform(:get, "/#{base_vaos_route}/patients/#{user.icn}/eligibility", params, headers)
        end
      end

      def get_patient_appointment_metadata_vpg(clinic_service_id, facility_id, type)
        params = {
          clinicalService: clinic_service_id,
          location: facility_id,
          type:
        }

        with_monitoring do
          perform(:get, "/vpg/v1/patients/#{user.icn}/eligibility", params, headers)
        end
      end

      def check_migrations(result, facility_id, type)
        migrations = VAOS::OhMigrationsHelper.get_migrations
        if migrations.key?(facility_id) && migrations[facility_id][:disable_eligibility]

          result[:eligible] = false
          result[:ineligibility_reasons] = [] unless result[:ineligibility_reasons]
          result[:ineligibility_reasons] <<
            {
              coding: [
                {
                  code: type == 'direct' ? 'facility-cs-direct-disabled' : 'facility-cs-request-disabled',
                  display: 'OH migration'
                }
              ]
            }
        end
      end
    end
  end
end
