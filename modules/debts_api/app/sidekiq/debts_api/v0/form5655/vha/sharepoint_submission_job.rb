# frozen_string_literal: true

require 'debt_management_center/sharepoint/request'

module DebtsApi
  class V0::Form5655::VHA::SharepointSubmissionJob
    include Sidekiq::Worker
    include SentryLogging
    STATS_KEY = 'api.vha_sharepoint_submission'

    sidekiq_options retry: 10
    sidekiq_retry_in { 1.hour.to_i }

    sidekiq_retries_exhausted do |job, ex|
      StatsD.increment("#{STATS_KEY}.failure") # Deprecate this in favor of exhausted naming convention below
      StatsD.increment("#{STATS_KEY}.retries_exhausted")
      submission_id = job['args'][0]
      submission = DebtsApi::V0::Form5655Submission.find(submission_id)
      submission.register_failure("SharePoint Submission Failed: #{job['error_message']}.")

      Rails.logger.error <<~LOG
        V0::Form5655::VHA::SharepointSubmissionJob retries exhausted:
        submission_id: #{submission_id}
        Exception: #{ex.message}
        Backtrace: #{ex.backtrace.join("\n")}
      LOG
    end

    #
    # Separate submission job for VHA SharePoint PDF uploads
    #
    # @submission_id {Form5655Submission} - FSR submission record
    #
    def perform(submission_id)
      # Use advisory lock to prevent multiple workers from uploading the same FSR
      DebtsApi::V0::Form5655Submission.with_advisory_lock("sharepoint-#{submission_id}", timeout_seconds: 15) do
        form_submission = DebtsApi::V0::Form5655Submission.find(submission_id)

        # Skip if already in final state
        if form_submission.submitted?
          Rails.logger.info('Skipping already submitted FSR', submission_id:)
          return
        end

        sharepoint_request = DebtManagementCenter::Sharepoint::Request.new
        Rails.logger.info('5655 Form Uploading to SharePoint API', submission_id:)

        begin
          sharepoint_request.upload(
            form_contents: form_submission.form,
            form_submission:,
            station_id: form_submission.form['facilityNum']
          )
          StatsD.increment("#{STATS_KEY}.success")
        rescue => e
          Rails.logger.error("SharePoint submission failed: #{e.message}", submission_id:)
          raise e
        end
      end
    end
  end
end
