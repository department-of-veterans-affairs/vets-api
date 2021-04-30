# frozen_string_literal: true

module VAOS
  module V2
    class SystemsService < VAOS::SessionService
      def get_facility_clinics(location_id, patient_icn, clinic_ids, clinical_service, page_size, page_number)
        with_monitoring do
          url = "/vaos/v1/locations/#{location_id}/clinics"
          url_params = {
            'location-id' => location_id,
            'patient-icn' => patient_icn,
            'clinic-ids' => clinic_ids,
            'clinical-service' => clinical_service,
            'page-size' => page_size,
            'page-number' => page_number
          }
          response = perform(:get, url, url_params, headers)
          response.body.map { |clinic| OpenStruct.new(clinic) }
        end
      end
    end
  end
end
