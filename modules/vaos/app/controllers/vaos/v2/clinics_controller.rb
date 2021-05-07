# frozen_string_literal: true

module VAOS
  module V2
    class ClinicsController < VAOS::V0::BaseController
      def index
        response = systems_service.get_facility_clinics(clinics_params)
        render json: VAOS::V2::ClinicsSerializer.new(response)
      end

      private

      def systems_service
        VAOS::V2::SystemsService.new(current_user)
      end

      def clinics_params
        params.require(:location_id)
        params.permit(
          :patient_icn,
          :clinic_ids,
          :clinical_service,
          :page_size,
          :page_number
        )
        params
      end
    end
  end
end
