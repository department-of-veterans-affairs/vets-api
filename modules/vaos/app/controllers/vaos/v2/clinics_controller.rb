# frozen_string_literal: true

module VAOS
  module V2
    class ClinicsController < VAOS::BaseController
      CLINIC_KEY = 'Clinic'

      def index
        response = systems_service.get_facility_clinics(location_id:,
                                                        clinic_ids: params[:clinic_ids],
                                                        clinical_service: params[:clinical_service],
                                                        page_size: params[:page_size],
                                                        page_number: params[:page_number])
        log_clinic_names(response)
        render json: VAOS::V2::ClinicsSerializer.new(response)
      end

      private

      def log_clinic_names(clinic_data)
        clinic_data.each do |clinic|
          clinic_names = { CLINIC_KEY => clinic_name_metrics(clinic) }
          Rails.logger.info('Clinic names returned', clinic_names.to_json) unless clinic_names.empty?
        end
      end

      def clinic_name_metrics(clinic)
        {
          stationId: clinic.station_id,
          serviceName: clinic.service_name
        }
      end

      def systems_service
        VAOS::V2::SystemsService.new(current_user)
      end

      def location_id
        params.require(:location_id)
      end
    end
  end
end
