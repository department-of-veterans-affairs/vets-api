# frozen_string_literal: true

module V0
  class CoeController < ApplicationController
    def status
      combined_status = lgy_service.get_determination_and_application
      render json: { status: combined_status }, status: :ok
    end

    private

    def lgy_service
      @lgy_service ||= LgyService.new(edipi: @current_user.edipi, icn: @current_user.icn)
    end
  end
end
