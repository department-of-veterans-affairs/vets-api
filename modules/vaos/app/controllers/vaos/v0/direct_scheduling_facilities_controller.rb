# frozen_string_literal: true

# VAOS V0 routes and controllers no longer in use
# :nocov:
module VAOS
  module V0
    class DirectSchedulingFacilitiesController < VAOS::V0::BaseController
      def index
        response = systems_service.get_system_facilities(
          facilities_params[:system_id],
          facilities_params[:parent_code],
          facilities_params[:type_of_care_id]
        )

        render json: VAOS::V0::DirectSchedulingFacilitySerializer.new(response)
      end

      private

      def systems_service
        VAOS::SystemsService.new(current_user)
      end

      def facilities_params
        params.require(%i[system_id type_of_care_id parent_code])
        params.permit(
          :parent_code,
          :system_id,
          :type_of_care_id
        )
      end
    end
  end
end
# :nocov:
