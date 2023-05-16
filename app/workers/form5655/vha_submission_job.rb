# frozen_string_literal: true

require 'debt_management_center/financial_status_report_service'

module Form5655
  class VHASubmissionJob
    include Sidekiq::Worker

    sidekiq_options retry: false

    def perform(submission_id, user_uuid)
      submission = Form5655Submission.find(submission_id)
      user = User.find(user_uuid)
      DebtManagementCenter::FinancialStatusReportService.new(user).submit_vha_fsr(submission)
    end
  end
end
