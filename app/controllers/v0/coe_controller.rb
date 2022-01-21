# frozen_string_literal: true

require 'lgy/service'
module V0
  class CoeController < ApplicationController
    def status
      coe_status = lgy_service.coe_status
      render json: { data: { attributes: coe_status } }, status: :ok
    end

    def download_coe
      coe_url = lgy_service.coe_url
      render json: { data: { attributes: { url: coe_url } } }, status: :ok
    end

    private

    def lgy_service
      @lgy_service ||= LGY::Service.new(edipi: @current_user.edipi, icn: @current_user.icn)
    end
  end
end
