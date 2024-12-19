require 'sidekiq'
require 'lighthouse/benefits_documents/constants'

module BenefitsDocuments
  class FailureNotificationEmailJob
    include Sidekiq::Job

    sidekiq_options retry: false, unique_for: 30.minutes

    FAILED_STATUS = BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED]
    MAILER_TEMPLATE_ID = NOTIFY_SETTINGS.template_id.evidence_submission_failure_email
    # TODO: need to add statsd logic
    # STATSD_KEY_PREFIX = ''

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
        response = notify_client.send_email(
          recipient_identifier: { id_value: upload.user_account.icn, id_type: 'ICN' },
          template_id: MAILER_TEMPLATE_ID,
          personalisation: upload.template_metadata_ciphertext.personalisation
        )

        record_email_send_success(upload, response)
      rescue => e
        record_email_send_failure(upload, e)
      end

      nil
    end

    def record_email_send_success(upload, response)
      EvidenceSubmission.update(id: upload.id, va_notify_id: response.id, va_notify_date: DateTime.now)
      error_message = "#{upload.job_class} va notify failure email queued"
      ::Rails.logger.info(error_message)
      StatsD.increment('silent_failure_avoided_no_confirmation',
                       tags: ['service:claim-status', "function: #{error_message}"])
    end

    def record_email_send_failure(upload, error)
      error_message = "#{upload.job_class} va notify failure email errored"
      ::Rails.logger.error(error_message, { message: error.message })
      StatsD.increment('silent_failure', tags: ['service:claim-status', "function: #{error_message}"])
      log_exception_to_sentry(e)
    end

    # add va_notify_date to the evidence_submissions table - done
    # grab failed records that dont have a va_notify_date - done
    # reach out to va notify with an id of the template - go off of what was in the
    # call for this job app/sidekiq/lighthouse/failure_notification.rb, no retrys
    # for each file - done
    # va notify should return an id when a record is created (take a look at record_evidence_email_send_successful() for an example)
    # update evidence submissions with a va notify id, and va notify date - done
    #
    # use job_class from the es table to determine if we
    # should send evss or lighthouse log - done
    # Update app/sidekiq/lighthouse/document_upload.rb method sidekiq_retries_exhausted()
    # and create a new record and set the upload status to FAILED - done
    # Update app/sidekiq/evss/document_upload.rb method sidekiq_retries_exhausted()
    # and set the upload status to FAILED - done
    #
    # Remove app/sidekiq/evss/failure_notification.rb and tests - done
    # Remove app/sidekiq/lighthouse/failure_notification.rb and tests - done
    # Update tests for doc upload lighthouse and evss
    # Add tests for failure notification email job
    #
    # update periodic_job.rb with your job
    # modules/decision_reviews/app/sidekiq/decision_reviews/failure_notification_email_job.rb
  end
end
