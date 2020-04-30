# frozen_string_literal: true

module VAOS
  module V0
    class FacilitiesController < VAOS::V0::BaseController
      def index
        response = systems_service.get_facilities(facilities_params)
        render json: VAOS::V0::FacilitySerializer.new(response)
      end

      private

      def systems_service
        VAOS::SystemsService.new(current_user)
      end

      def facilities_params
        params.require(:facility_codes)
      end
    end
  end
end
