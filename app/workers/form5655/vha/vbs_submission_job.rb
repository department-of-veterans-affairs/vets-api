# frozen_string_literal: true

require 'debt_management_center/vbs/request'
require 'debt_management_center/workers/va_notify_email_job'

module Form5655
  module VHA
    class VBSSubmissionJob
      include Sidekiq::Worker
      include SentryLogging

      sidekiq_options retry: false

      EMAIL_TEMPLATE = Settings.vanotify.services.dmc.template_id.vha_fsr_confirmation_email

      #
      # Allow for submitting to VBS API without existing user object
      #
      # @submission_id {Form5655Submission} - FSR submission record
      #
      def perform(submission_id)
        submission = Form5655Submission.find(submission_id)
        form = submission.form
        form['transactionId'] = submission.id
        form['timestamp'] = submission.created_at.strftime('%Y%m%dT%H%M%S')

        vbs_request = DebtManagementCenter::VBS::Request.build
        response = vbs_request.post('/vbsapi/UploadFSRJsonDocument', { jsonDocument: form.to_json })
        if response.success?
          personalization = {
            'name' => form['personalData']['veteranFullName']['first'],
            'time' => '48 hours',
            'date' => Time.zone.now.strftime('%m/%d/%Y')
          }

          DebtManagementCenter::VANotifyEmailJob.perform_async(form['personalData']['emailAddress'],
                                                               EMAIL_TEMPLATE,
                                                               personalization)
        end
      end
    end
  end
end
