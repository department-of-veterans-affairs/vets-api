# frozen_string_literal: true

module VAOS
  module V2
    class ClinicsController < VAOS::V0::BaseController
      def index
        response = systems_service.get_facility_clinics(
          clinics_params[:location_id],
          clinics_params[:patient_icn],
          clinics_params[:clinic_ids],
          clinics_params[:clinical_service],
          clinics_params[:page_size],
          clinics_params[:page_number]
        )

        render json: VAOS::V2::ClinicsSerializer.new(response)
      end

      private

      def systems_service
        VAOS::V2::SystemsService.new(current_user)
      end

      def clinics
        @clinics ||=
          systems_service.get_facility_clinics()
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
      end
    end
  end
end
