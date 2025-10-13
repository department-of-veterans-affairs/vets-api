# frozen_string_literal: true

require 'debts_api/v0/financial_status_report_service'

module DebtsApi
  class V0::Form5655::VBASubmissionJob
    include Sidekiq::Job
    STATS_KEY = 'api.vba_submission'

    sidekiq_options retry: 5
    sidekiq_retry_in { 1.hour.to_i }

    class MissingUserAttributesError < StandardError; end

    sidekiq_retries_exhausted do |job, ex|
      StatsD.increment("#{STATS_KEY}.retries_exhausted")
      submission_id = job['args'][0]
      user_uuid = job['args'][1]

      submission = DebtsApi::V0::Form5655Submission.find_by(id: submission_id)
      submission&.register_failure("VBASubmissionJob#perform: #{ex.message}")

      Rails.logger.error <<~LOG
        V0::Form5655::VBASubmissionJob retries exhausted:
        submission_id: #{submission_id} | user_id: #{user_uuid}
        Exception: #{ex.class} - #{ex.message}
        Backtrace: #{ex.backtrace.join("\n")}
      LOG
    end

    def perform(submission_id, user_uuid)
      @submission_id = submission_id
      @user_uuid = user_uuid

      # Try Redis
      user = UserProfileAttributes.find(user_uuid)

      # Fall back to form data
      if user.nil?
        StatsD.increment("#{STATS_KEY}.user_data_fallback_used")
        user = build_user_from_form_data
      end

      raise MissingUserAttributesError, user_uuid unless user

      DebtsApi::V0::FinancialStatusReportService.new(user).submit_vba_fsr(submission.form)
      UserProfileAttributes.find(@user_uuid)&.destroy
      StatsD.increment("#{STATS_KEY}.success")
      submission.register_success
    rescue => e
      StatsD.increment("#{STATS_KEY}.failure")
      Rails.logger.error("V0::Form5655::VBASubmissionJob failed, retrying: #{e.message}")
      raise e
    end

    private

    def submission
      @submission ||= DebtsApi::V0::Form5655Submission.find(@submission_id)
    end

    def build_user_from_form_data
      ipf_data = submission.ipf_form

      return nil unless ipf_data['personal_data']

      email = ipf_data.dig('personal_data', 'email_address')
      full_name = ipf_data.dig('personal_data', 'veteran_full_name') || {}

      OpenStruct.new(
        email:,
        first_name: full_name['first'] || 'Veteran',
        last_name: full_name['last'] || '',
        uuid: @user_uuid
      )
    end
  end
end
