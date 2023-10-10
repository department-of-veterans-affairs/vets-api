# frozen_string_literal: true

require 'debt_management_center/financial_status_report_service'

module Form5655
  class VBASubmissionJob
    include Sidekiq::Job
    include SentryLogging
    STATS_KEY = 'api.vba_submission'

    sidekiq_options retry: 4

    class MissingUserAttributesError < StandardError; end

    sidekiq_retries_exhausted do |job, _ex|
      StatsD.increment("#{STATS_KEY}.failure")
      submission_id = job['args'][0]
      user_uuid = job['args'][1]
      UserProfileAttributes.find(user_uuid)&.destroy
      submission = DebtsApi::V0::Form5655Submission.find(submission_id)
      submission.register_failure("VBA Submission Failed: #{job['error_message']}.")
    end

    def perform(submission_id, user_uuid)
      submission = Form5655Submission.find(submission_id)
      user = UserProfileAttributes.find(user_uuid)
      raise MissingUserAttributesError, user_uuid unless user

      DebtManagementCenter::FinancialStatusReportService.new(user).submit_vba_fsr(submission.form)
      user.destroy
      submission.submitted!
      StatsD.increment("#{stats_key}.success")
    end
  end
end
