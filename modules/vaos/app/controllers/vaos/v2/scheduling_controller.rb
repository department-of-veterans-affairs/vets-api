# frozen_string_literal: true

module VAOS
  module V2
    class SchedulingController < VAOS::BaseController
      def configurations
        response = mobile_facility_service.get_scheduling_configurations(csv_facility_ids, params[:cc_enabled])
        render json: VAOS::V2::SchedulingConfigurationSerializer.new(response[:data], meta: response[:meta])
      end

      private

      def mobile_facility_service
        VAOS::V2::MobileFacilityService.new(current_user)
      end

      def csv_facility_ids
        ids = params.require(:facility_ids)
        ids.is_a?(Array) ? ids.to_csv(row_sep: nil) : ids
      end
    end
  end
end
