# frozen_string_literal: true

module DebtManagementCenter
  class FinancialStatusReportResponse
    def initialize(res)
      @res = res
    end

    def status
      @res['status']
    end
  end
end
