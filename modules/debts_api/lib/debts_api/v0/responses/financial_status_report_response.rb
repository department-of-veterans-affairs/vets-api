# frozen_string_literal: true

require 'debt_management_center/models/financial_status_report'

module DebtsApi
  class V0::FinancialStatusReportResponse
    attr_reader :status, :filenet_id

    def initialize(response_body)
      @response_body = response_body
      @status = @response_body['status']
      @filenet_id = @response_body['identifier']
    end

    def to_h
      { response_body: @response_body }
    end
  end
end
