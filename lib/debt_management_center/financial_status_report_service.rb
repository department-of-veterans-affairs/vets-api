# frozen_string_literal: true

require 'debt_management_center/base_service'
require 'debt_management_center/financial_status_report_configuration'
require 'debt_management_center/responses/financial_status_report_response'

module DebtManagementCenter
  class FinancialStatusReportService < DebtManagementCenter::BaseService
    configuration DebtManagementCenter::FinancialStatusReportConfiguration
    STATSD_KEY_PREFIX = 'api.dmc'

    def submit_financial_status_report(form)
      with_monitoring_and_error_handling do
        form = camelize(form)
        DebtManagementCenter::FinancialStatusReportResponse.new(
          perform(:post, 'financial-status-report/formtopdf', form).body
        )
      end
    end

    private

    def camelize(hash)
      hash.deep_transform_keys! { |key| key.to_s.camelize(:lower) }
    end
  end
end
