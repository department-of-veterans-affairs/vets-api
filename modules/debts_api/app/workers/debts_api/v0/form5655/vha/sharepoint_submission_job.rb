# frozen_string_literal: true

require 'debt_management_center/sharepoint/request'

module DebtsApi
  class V0::Form5655::VHA::SharepointSubmissionJob
    include Sidekiq::Worker
    include SentryLogging

    sidekiq_options retry: false

    #
    # Separate submission job for VHA SharePoint PDF uploads
    #
    # @submission_id {Form5655Submission} - FSR submission record
    #
    def perform(submission_id)
      form_submission = DebtsApi::V0::Form5655Submission.find(submission_id)
      sharepoint_request = DebtManagementCenter::Sharepoint::Request.new

      Rails.logger.info('5655 Form Uploading to SharePoint API', submission_id:)

      sharepoint_request.upload(
        form_contents: form_submission.form,
        form_submission:,
        station_id: form_submission.form['facilityNum']
      )
    rescue => e
      form_submission.register_failure("SharePoint Submission Failed: #{e.message}.")
      raise e
    end
  end
end
