# frozen_string_literal: true

module DebtsApi
  class V0::Form5655::VBASubmissionJob
    include Sidekiq::Worker

    sidekiq_options retry: false

    def perform(submission_id, user_uuid)
      submission = DebtsApi::V0::Form5655Submission.find(submission_id)
      user = User.find(user_uuid)
      DebtsApi::V0::FinancialStatusReportService.new(user).submit_vba_fsr(submission.form)
    end
  end
end
