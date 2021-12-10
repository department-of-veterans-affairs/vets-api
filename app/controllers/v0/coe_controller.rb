# frozen_string_literal: true

require 'lgy/service'
module V0
  class CoeController < ApplicationController
    def status
      coe_status = lgy_service.coe_status
      render json: { data: { attributes: { status: coe_status } } }, status: :ok
    end

    private

    def lgy_service
      @lgy_service ||= LGY::Service.new(edipi: @current_user.edipi, icn: @current_user.icn)
    end
  end
end
