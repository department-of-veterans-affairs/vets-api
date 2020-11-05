# frozen_string_literal: true

require 'dmc/fsr_service'

module V0
  class FinancialStatusReportsController < ApplicationController
    skip_before_action :verify_authenticity_token

    def create
      render json: service.submit_financial_status_report(params)
    end

    private

    def service
      DMC::FSRService.new
    end
  end
end
