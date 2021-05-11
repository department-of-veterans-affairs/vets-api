# frozen_string_literal: true

module VAOS
  module V2
    class SchedulingController < VAOS::V0::BaseController
      def configurations
        response = systems_service.get_scheduling_configurations(configuration_params)
        render json: VAOS::V2::SchedulingConfurationSerializer.new(response)
      end

      private

      def configuration_params
        params.require(:facility_ids)
        params.permit(:cc_enabled, :facility_ids)
      end

      def mobile_facility_service
        VAOS::V2::MobileFacilityService.new(current_user)
      end
    end
  end
end
