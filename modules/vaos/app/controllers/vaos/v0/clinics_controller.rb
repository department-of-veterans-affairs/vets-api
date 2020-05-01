# frozen_string_literal: true

module VAOS
  module V0
    class ClinicsController < VAOS::V0::BaseController
      def index
        response = systems_service.get_facility_clinics(
          clinics_params[:facility_id],
          clinics_params[:type_of_care_id],
          clinics_params[:system_id]
        )

        render json: VAOS::V0::ClinicSerializer.new(response)
      end

      private

      def systems_service
        VAOS::SystemsService.new(current_user)
      end

      def clinics_params
        params.require(:facility_id)
        params.require(:type_of_care_id)
        params.require(:system_id)
        params.permit(
          :facility_id,
          :type_of_care_id,
          :system_id
        )
      end
    end
  end
end
