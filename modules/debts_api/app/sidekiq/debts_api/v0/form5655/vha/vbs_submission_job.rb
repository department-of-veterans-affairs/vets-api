# frozen_string_literal: true

require 'debts_api/v0/financial_status_report_service'

module DebtsApi
  class V0::Form5655::VHA::VBSSubmissionJob
    include Sidekiq::Worker
    include SentryLogging
    STATS_KEY = 'api.vbs_submission'

    sidekiq_options retry: 4

    class MissingUserAttributesError < StandardError; end

    sidekiq_retries_exhausted do |job, ex|
      StatsD.increment("#{STATS_KEY}.failure") # Deprecate this in favor of exhausted naming convention below
      StatsD.increment("#{STATS_KEY}.retries_exhausted")
      submission_id = job['args'][0]
      user_uuid = job['args'][1]

      submission = DebtsApi::V0::Form5655Submission.find(submission_id)
      submission.register_failure("VBS Submission Failed: #{ex.message}")

      Rails.logger.error <<~LOG
        V0::Form5655::VHA::VBSSubmissionJob retries exhausted:
        submission_id: #{submission_id} | user_id: #{user_uuid}
        Exception: #{ex.class} - #{ex.message}
        Backtrace: #{ex.backtrace.join("\n")}
      LOG
    end

    def perform(submission_id, user_uuid)
      submission = DebtsApi::V0::Form5655Submission.find(submission_id)
      user = UserProfileAttributes.find(user_uuid)
      raise MissingUserAttributesError, user_uuid unless user

      DebtsApi::V0::FinancialStatusReportService.new(user).submit_to_vbs(submission)
      user.destroy
      StatsD.increment("#{STATS_KEY}.success")
    end
  end
end
