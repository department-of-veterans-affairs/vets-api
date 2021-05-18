# frozen_string_literal: true

module VAOS
  module V2
    class ClinicsController < VAOS::V0::BaseController
      def index
        response = systems_service.get_facility_clinics(location_id: location_id,
                                                        clinic_ids: params[:clinic_ids],
                                                        clinical_service: params[:clinical_service],
                                                        page_size: params[:page_size],
                                                        page_number: params[:page_number])
        render json: VAOS::V2::ClinicsSerializer.new(response)
      end

      private

      def systems_service
        VAOS::V2::SystemsService.new(current_user)
      end

      def location_id
        params.require(:location_id)
      end
    end
  end
end
