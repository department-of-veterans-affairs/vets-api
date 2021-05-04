# frozen_string_literal: true

require 'common/exceptions'
require 'common/client/errors'
require 'json'

module VAOS
  module V2
    class PatientsService < VAOS::SessionService
      def get_patient_appointment_metadata(clinic_service_id, facility_id, type)
        params = {
          clinical_service_id: clinic_service_id,
          facility_id: facility_id,
          type: type
        }

        with_monitoring do
          response = perform(:get, url, params, headers)
          OpenStruct.new(response.body.merge(id: SecureRandom.hex(2)))
        end
      end

      private

      def url
        "/vaos/v1/patients/#{user.icn}"
      end
    end
  end
end
