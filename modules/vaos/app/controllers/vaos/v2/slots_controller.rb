# frozen_string_literal: true

module VAOS
  module V2
    class SlotsController < VAOS::BaseController
      def index
        response = systems_service.get_available_slots(location_id: location_id,
                                                       clinic_id: clinic_id,
                                                       start_dt: start_dt,
                                                       end_dt: end_dt)
        render json: VAOS::V2::SlotsSerializer.new(response)
      end

      private

      def systems_service
        VAOS::V2::SystemsService.new(current_user)
      end

      def location_id
        params.require(:location_id)
      end

      def clinic_id
        params.require(:clinic_id)
      end

      def start_dt
        params.require(:start)
      end

      def end_dt
        params.require(:end)
      end
    end
  end
end
