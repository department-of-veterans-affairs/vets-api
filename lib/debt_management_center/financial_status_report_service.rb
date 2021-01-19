# frozen_string_literal: true

require 'debt_management_center/base_service'
require 'debt_management_center/financial_status_report_configuration'
require 'debt_management_center/responses/financial_status_report_response'
require 'debt_management_center/models/financial_status_report'

module DebtManagementCenter
  class FinancialStatusReportService < DebtManagementCenter::BaseService
    configuration DebtManagementCenter::FinancialStatusReportConfiguration
    STATSD_KEY_PREFIX = 'api.dmc'

    def submit_financial_status_report(form)
      with_monitoring_and_error_handling do
        form = camelize(form)
        byebug
        DebtManagementCenter::FinancialStatusReportResponse.new(
          perform(:post, 'financial-status-report/formtopdf', form).body
        )
      end
    end

    def get_pdf
      financial_status_report = DebtManagementCenter::FinancialStatusReport.find(@current_user.uuid)
      perform(
        :get, 'financial-status-report/documentstream', objectId: financial_status_report.filenet_id
      ).body
    end

    private

    def camelize(hash)
      hash.deep_transform_keys! { |key| key.to_s.camelize(:lower) }
    end
  end
end
