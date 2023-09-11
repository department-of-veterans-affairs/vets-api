# frozen_string_literal: true

require 'debt_management_center/sharepoint/request'

module Form5655
  module VHA
    class SharepointSubmissionJob
      include Sidekiq::Worker
      include SentryLogging

      sidekiq_options retry: false

      #
      # Separate submission job for VHA SharePoint PDF uploads
      #
      # @submission_id {Form5655Submission} - FSR submission record
      #
      def perform(submission_id)
        form_submission = Form5655Submission.find(submission_id)
        sharepoint_request = DebtManagementCenter::Sharepoint::Request.new

        sharepoint_request.upload(
          form_contents: form_submission.form,
          form_submission:,
          station_id: form_submission.form['facilityNum']
        )
      end
    end
  end
end
