# frozen_string_literal: true

module VAOS
  module V0
    class LimitsController < VAOS::V0::BaseController
      def index
        response = systems_service.get_facility_limits(
          facility_id,
          type_of_care_id
        )

        render json: VAOS::V0::LimitSerializer.new(response)
      end

      private

      def systems_service
        VAOS::SystemsService.new(current_user)
      end

      def facility_id
        params.require(:facility_id)
      end

      def type_of_care_id
        params.require(:type_of_care_id)
      end
    end
  end
end
