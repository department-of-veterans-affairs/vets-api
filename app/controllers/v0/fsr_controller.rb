# frozen_string_literal: true

require 'dmc/fsr_service'

module V0
  class FSRController < ApplicationController
    def create
      render json: service.submit_financial_status_report(params)
    end

    private

    def service
      DMC::FSRService.new(@current_user)
    end
  end
end
