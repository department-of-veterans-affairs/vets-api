# frozen_string_literal: true

require 'debt_management_center/financial_status_report_service'

module Form5655
  module VBA
    class DmcSubmissionJob
      include Sidekiq::Worker
      include SentryLogging

      sidekiq_options retry: false

      def perform(submission_id)
        submission = Form5655Submission.find(submission_id)

        DebtManagementCenter::FinancialStatusReportService.new.submit_vba_fsr(submission.form)
      end
    end
  end
end
