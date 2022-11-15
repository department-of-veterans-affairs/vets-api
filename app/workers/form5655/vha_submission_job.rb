# frozen_string_literal: true

module Form5655
  class VHASubmissionJob
    include Sidekiq::Worker

    def perform(submission_id, user_uuid)
      submission = Form5655Submission.find(submission_id)
      user = User.find(user_uuid)
      DebtManagementCenter::FinancialStatusReportService.new(user).submit_vha_fsr(submission)
    end
  end
end
