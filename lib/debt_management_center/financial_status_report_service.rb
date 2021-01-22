# frozen_string_literal: true

require 'debt_management_center/base_service'
require 'debt_management_center/financial_status_report_configuration'
require 'debt_management_center/responses/financial_status_report_response'
require 'debt_management_center/models/financial_status_report'
require 'debt_management_center/financial_status_report_downloader'

module DebtManagementCenter
  ##
  # Service that integrates with the Debt Management Center's Financial Status Report endpoints.
  # Allows users to submit financial status reports, and download copies of completed reports.
  #
  class FinancialStatusReportService < DebtManagementCenter::BaseService
    configuration DebtManagementCenter::FinancialStatusReportConfiguration

    STATSD_KEY_PREFIX = 'api.dmc'

    def initialize(user)
      @user = user
    end

    ##
    # Submit a financial status report to the Debt Management Center
    #
    # @param form [JSON] JSON serialized form data of a Financial Status Report form (VA-5655)
    # @return [Hash]
    #
    def submit_financial_status_report(form)
      with_monitoring_and_error_handling do
        form = camelize(form)
        response = DebtManagementCenter::FinancialStatusReportResponse.new(
          perform(:post, 'financial-status-report/formtopdf', form).body
        )
        update_filenet_id(response.filenet_id)
        { status: response.status }
      end
    end

    ##
    # Downloads a copy of a user's filled Financial Status Report (VA-5655)
    #
    # @return [String]
    #
    def get_pdf
      financial_status_report = DebtManagementCenter::FinancialStatusReport.find(@user.uuid)
      downloader = DebtManagementCenter::FinancialStatusReportDownloader.new(financial_status_report)
      downloader.download_pdf
    end

    private

    def update_filenet_id(filenet_id)
      fsr_params = Hash[REDIS_CONFIG[:financial_status_report][:namespace], @user.uuid]
      pdf = DebtManagementCenter::FinancialStatusReport.new(fsr_params)
      pdf.update(filenet_id: filenet_id, uuid: @user.uuid)
    end

    def camelize(hash)
      hash.deep_transform_keys! { |key| key.to_s.camelize(:lower) }
    end
  end
end
