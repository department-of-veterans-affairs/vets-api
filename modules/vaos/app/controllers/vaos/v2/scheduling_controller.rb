# frozen_string_literal: true

module VAOS
  module V2
    class SchedulingController < VAOS::V0::BaseController
      def configurations
        facility_ids = configuration_params[:facility_ids]
        cc_enabled = configuration_params[:cc_enabled]

        response = mobile_facility_service.get_scheduling_configurations(facility_ids, cc_enabled)
        render json: VAOS::V2::SchedulingConfigurationSerializer.new(response[:data], meta: response[:meta])
      end

      private

      def configuration_params
        params.require(:facility_ids)
        params.permit(:cc_enabled, facility_ids: [])
      end

      def mobile_facility_service
        VAOS::V2::MobileFacilityService.new(current_user)
      end
    end
  end
end
