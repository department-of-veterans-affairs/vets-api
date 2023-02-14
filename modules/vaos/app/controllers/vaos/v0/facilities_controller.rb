# frozen_string_literal: true

# VAOS V0 routes and controllers no longer in use
# :nocov:
module VAOS
  module V0
    class FacilitiesController < VAOS::V0::BaseController
      def index
        response = systems_service.get_facilities(facilities_params)
        render json: VAOS::V0::FacilitySerializer.new(response)
      end

      def limits
        response = systems_service.get_facilities_limits(facility_ids, type_of_care_id)
        render json: VAOS::V0::LimitSerializer.new(response)
      end

      private

      def facility_ids
        params.require(:facility_ids)
      end

      def type_of_care_id
        params.require(:type_of_care_id)
      end

      def systems_service
        VAOS::SystemsService.new(current_user)
      end

      def facilities_params
        params.require(:facility_codes)
      end
    end
  end
end
# :nocov:
