# frozen_string_literal: true

module VAOS
  module V2
    class FacilitiesController < VAOS::V0::BaseController
      def index
        response = mobile_facility_service.get_facilities(clinics_params)
        render json: VAOS::V2::FacilitiesSerializer.new(response)
      end

      private

      def mobile_facility_service
        VAOS::V2::MobileFacilityService.new(current_user)
      end

      def clinics_params
        params.require(:ids)
        params.permit(
          :ids,
          :children,
          :type
        )
      end
    end
  end
end
