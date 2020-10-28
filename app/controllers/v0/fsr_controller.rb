# frozen_string_literal: true

require 'dmc/fsr_service'

module V0
  class FSRController < ApplicationController
    def index
      render json: service.submit_financial_status_report(fsr_params)
    end

    private

    def fsr_params
      params
    end

    def service
      DMC::FSRService.new(@current_user)
    end
  end
end