# frozen_string_literal: true

require 'debts_api/v0/financial_status_report_service'

module DebtsApi
  class V0::Form5655::VHASubmissionJob
    include Sidekiq::Job
    include SentryLogging
    STATS_KEY = 'api.vha_submission'

    sidekiq_options retry: false

    class MissingUserAttributesError < StandardError; end

    sidekiq_retries_exhausted do |job, _ex|
      StatsD.increment("#{STATS_KEY}.retries_exhausted")
      submission_id = job['args'][0]
      user_uuid = job['args'][1]
      Rails.logger.error <<~LOG
        V0::Form5655::VHASubmissionJob retries exhausted:
        Exception: #{ex.class} - #{ex.message}
        Backtrace: #{ex.backtrace.join("\n")}
        submission_id: #{submission_id} | user_id: #{user_uuid}
      LOG
      UserProfileAttributes.find(user_uuid)&.destroy
    end

    def perform(submission_id, user_uuid)
      submission = DebtsApi::V0::Form5655Submission.find(submission_id)
      user = UserProfileAttributes.find(user_uuid)
      raise MissingUserAttributesError, user_uuid unless user

      DebtsApi::V0::FinancialStatusReportService.new(user).submit_vha_fsr(submission)
      user.destroy
      StatsD.increment("#{STATS_KEY}.success")
      submission.register_success
    rescue => e
      submission.register_failure(e.message)
      StatsD.increment("#{STATS_KEY}.failure")
      raise e
    end
  end
end