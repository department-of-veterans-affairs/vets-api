require 'sidekiq'
require 'lighthouse/benefits_documents/constants'

module BenefitsDocuments
  class FailureNotificationEmailJob
    include Sidekiq::Job

    sidekiq_options retry: false, unique_for: 30.minutes

    FAILED_STATUS = BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED]

    # TODO: need to add statsd logic
    # STATSD_KEY_PREFIX = ''
    #
    #

    def perform
      return unless should_perform?

      send_failed_evidence_submissions

      nil
    end

    def should_perform?
      failed_uploads.present?
    end

    # Fetches FAILED evidence submission records for BenefitsDocuments that dont have a va_notify_date
    def failed_uploads
      @failed_uploads ||= EvidenceSubmission.va_notify_email_not_sent
    end

    def notify_client
      VaNotify::Service.new(NOTIFY_SETTINGS.api_key)
    end

    def send_failed_evidence_submissions
      failed_uploads.each do |upload|
        notify_client.send_email(
          recipient_identifier: { id_value: icn, id_type: 'ICN' },
          template_id: MAILER_TEMPLATE_ID,
          personalisation: { first_name: upload.first_name, filename: upload.file_name, date_submitted:, date_failed: }
        )
      end

      nil
    end

    # add va_notify_date to the evidence_submissions table - done
    # grab failed records that dont have a va_notify_date - done
    # reach out to va notify with an id of the template - go off of what was in the
    # call for this job app/sidekiq/lighthouse/failure_notification.rb, no retrys
    # for each file
    # va notify should return an id when a record is created (take a look at record_evidence_email_send_successful() for an example)
    # update evidence submissions with a va notify id, and va notify date
    #
    # use job_class from the es table to determine if we
    # should send evss or lighthouse log
    # Update app/sidekiq/lighthouse/document_upload.rb method sidekiq_retries_exhausted()
    # and create a new record and set the upload status to FAILED
    # Update app/sidekiq/evss/document_upload.rb method sidekiq_retries_exhausted()
    # and set the upload status to FAILED
    #
    # Remove app/sidekiq/evss/failure_notification.rb and tests
    # Remove app/sidekiq/lighthouse/failure_notification.rb and tests
    # Update tests, add tests
    #
    # update periodic_job.rb with your job
    # modules/decision_reviews/app/sidekiq/decision_reviews/failure_notification_email_job.rb
    # add the date va_notify_date
  end
end
