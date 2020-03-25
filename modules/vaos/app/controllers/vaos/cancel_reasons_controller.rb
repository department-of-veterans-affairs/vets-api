# frozen_string_literal: true

module VAOS
  class CancelReasonsController < VAOS::BaseController
    def index
      response = systems_service.get_cancel_reasons(params[:facility_id])
      render json: VAOS::CancelReasonSerializer.new(response)
    end

    private

    def systems_service
      VAOS::SystemsService.new(current_user)
    end
  end
end
