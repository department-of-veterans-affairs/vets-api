# frozen_string_literal: true

module VAOS
  module V2
    class SystemsService < VAOS::SessionService
      def get_facility_clinics(clinics_params)
        with_monitoring do
          url = "/vaos/v1/locations/#{clinics_params[:location_id]}/clinics"
          url_params = {
            'location-id' => clinics_params[:location_id],
            'patient-icn' => clinics_params[:patient_icn],
            'clinic-ids' => clinics_params[:clinic_ids],
            'clinical-service' => clinics_params[:clinical_service],
            'page-size' => clinics_params[:page_size],
            'page-number' => clinics_params[:page_number]
          }
          response = perform(:get, url, url_params, headers)
          response.body.map { |clinic| OpenStruct.new(clinic) }
        end
      end
    end
  end
end
