# frozen_string_literal: true

module VAOS
  module V0
    class CancelReasonsController < VAOS::V0::BaseController
      def index
        response = systems_service.get_cancel_reasons(params[:facility_id])
        render json: VAOS::V0::CancelReasonSerializer.new(response)
      end

      private

      def systems_service
        VAOS::SystemsService.new(current_user)
      end
    end
  end
end
