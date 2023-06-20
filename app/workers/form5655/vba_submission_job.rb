# frozen_string_literal: true

require 'debt_management_center/financial_status_report_service'

module Form5655
  class VBASubmissionJob
    include Sidekiq::Worker
    include SentryLogging

    sidekiq_options retry: false

    class MissingUserAttributesError < StandardError; end

    sidekiq_retries_exhausted do |job, _ex|
      user_uuid = job['args'][1]
      UserProfileAttributes.find(user_uuid)&.destroy
    end

    def perform(submission_id, user_uuid)
      submission = Form5655Submission.find(submission_id)
      user = UserProfileAttributes.find(user_uuid)
      raise MissingUserAttributesError, user_uuid unless user

      DebtManagementCenter::FinancialStatusReportService.new(user).submit_vba_fsr(submission.form)
      user.destroy
    end
  end
end
