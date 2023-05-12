# frozen_string_literal: true

require 'debt_management_center/models/financial_status_report'

module FinancialStatusReportHelpers
  def set_filenet_id(opts)
    pdf = DebtManagementCenter::FinancialStatusReport.find_or_build(opts[:user].uuid)
    pdf.update(filenet_id: opts[:filenet_id], uuid: opts[:user].uuid)
  end
end
