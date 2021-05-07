# frozen_string_literal: true

module VAOS
  module V2
    class SlotsController < VAOS::V0::BaseController
      def index
        response = systems_service.get_available_slots(slots_params)
        render json: VAOS::V2::SlotsSerializer.new(response)
      end

      private

      def systems_service
        VAOS::V2::SystemsService.new(current_user)
      end

      def slots_params
        params.require(%i[location_id clinic_id start end])
        params.permit(:location_id, :clinic_id, :start, :end)
      end
    end
  end
end
