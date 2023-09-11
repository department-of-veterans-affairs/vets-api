# frozen_string_literal: true

require 'debts_api/v0/financial_status_report_service'

module DebtsApi
  class V0::Form5655::VHASubmissionJob
    include Sidekiq::Worker
    include SentryLogging

    sidekiq_options retry: false

    class MissingUserAttributesError < StandardError; end

    sidekiq_retries_exhausted do |job, _ex|
      user_uuid = job['args'][1]
      UserProfileAttributes.find(user_uuid)&.destroy
    end

    def perform(submission_id, user_uuid)
      submission = DebtsApi::V0::Form5655Submission.find(submission_id)
      user = UserProfileAttributes.find(user_uuid)
      raise MissingUserAttributesError, user_uuid unless user

      DebtsApi::V0::FinancialStatusReportService.new(user).submit_vha_fsr(submission)
      user.destroy
    end
  end
end
