# frozen_string_literal: true

require 'debt_management_center/models/financial_status_report'

module DebtManagementCenter
  class FinancialStatusReportResponse
    attr_reader :status, :filenet_id

    def initialize(res)
      @res = res
      @status = @res['status']
      @filenet_id = @res['identifier']
    end
  end
end
