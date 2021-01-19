# frozen_string_literal: true

require 'debt_management_center/models/financial_status_report'

module DebtManagementCenter
  class FinancialStatusReportResponse
    def initialize(res)
      @res = res
      update_filenet_id
    end

    def status
      @res['status']
    end

    private

    def update_filenet_id
      fsr_params = Hash[REDIS_CONFIG[:mdot][:namespace], @current_user.uuid]
      pdf = DebtManagementCenter::FinancialStatusReport.new(fsr_params)
      pdf.update(filenet_id: @res[:identifier], uuid: @current_user.uuid)
    end
  end
end
