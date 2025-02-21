# frozen_string_literal: true

require 'logging/call_location'
require 'zero_silent_failures/monitor'

module EVSS
  module DisabilityCompensationForm
    class SubmitUploads < Job
      STATSD_KEY_PREFIX = 'worker.evss.submit_form526_upload'
      ZSF_DD_TAG_FUNCTION = '526_evidence_upload_failure_email_queuing'

      # retry for  2d 1h 47m 12s
      # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
      sidekiq_options retry: 16

      sidekiq_retries_exhausted do |msg, _ex|
        job_id = msg['jid']
        error_class = msg['error_class']
        error_message = msg['error_message']
        timestamp = Time.now.utc
        form526_submission_id = msg['args'].first
        upload_data = msg['args'][1]

        # Match existing data check in perform method
        upload_data = upload_data.first if upload_data.is_a?(Array)
        log_info = { job_id:, error_class:, error_message:, timestamp:, form526_submission_id: }

        Rails.logger.warn('Submit Form 526 Upload Retries exhausted', log_info)

        form_job_status = Form526JobStatus.find_by(job_id:)
        bgjob_errors = form_job_status.bgjob_errors || {}
        new_error = {
          "#{timestamp.to_i}": {
            caller_method: __method__.to_s,
            error_class:,
            error_message:,
            timestamp:,
            form526_submission_id:
          }
        }
        form_job_status.update(
          status: Form526JobStatus::STATUS[:exhausted],
          bgjob_errors: bgjob_errors.merge(new_error)
        )

        StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted")

        if Flipper.enabled?(:disability_compensation_use_api_provider_for_submit_veteran_upload)
          submission = Form526Submission.find(form526_submission_id)

          provider = api_upload_provider(submission, upload_data['attachmentId'], nil)
          provider.log_uploading_job_failure(self, error_class, error_message)
        end

        if Flipper.enabled?(:form526_send_document_upload_failure_notification)
          guid = upload_data['confirmationCode']
          Form526DocumentUploadFailureEmail.perform_async(form526_submission_id, guid)
        end
        # NOTE: do NOT add any additional code here between the failure email being enqueued and the rescue block.
        # The mailer prevents an upload from failing silently, since we notify the veteran and provide a workaround.
        # The rescue will catch any errors in the sidekiq_retries_exhausted block and mark a "silent failure".
        # This shouldn't happen if an email was sent; there should be no code here to throw an additional exception.
        # The mailer should be the last thing that can fail.
      rescue => e
        cl = caller_locations.first
        call_location = Logging::CallLocation.new(ZSF_DD_TAG_FUNCTION, cl.path, cl.lineno)
        zsf_monitor = ZeroSilentFailures::Monitor.new(Form526Submission::ZSF_DD_TAG_SERVICE)
        user_account_id = begin
          Form526Submission.find(form526_submission_id).user_account_id
        rescue
          nil
        end

        zsf_monitor.log_silent_failure(log_info, user_account_id, call_location:)

        ::Rails.logger.error(
          'Failure in SubmitUploads#sidekiq_retries_exhausted',
          {
            messaged_content: e.message,
            job_id:,
            submission_id: form526_submission_id,
            pre_exhaustion_failure: {
              error_class:,
              error_message:
            }
          }
        )
        raise e
      end

      def self.api_upload_provider(submission, document_type, supporting_evidence_attachment)
        user = User.find(submission.user_uuid)

        ApiProviderFactory.call(
          type: ApiProviderFactory::FACTORIES[:supplemental_document_upload],
          options: {
            form526_submission: submission,
            document_type:,
            statsd_metric_prefix: STATSD_KEY_PREFIX,
            supporting_evidence_attachment:
          },
          current_user: user,
          feature_toggle: ApiProviderFactory::FEATURE_TOGGLE_SUBMIT_VETERAN_UPLOADS
        )
      end

      # Recursively submits a file in a new instance of this job for each upload in the uploads list
      #
      # @param submission_id [Integer] The {Form526Submission} id
      # @param upload_data [String] Form metadata for attachment, including upload GUID in AWS S3
      #
      def perform(submission_id, upload_data)
        Sentry.set_tags(source: '526EZ-all-claims')
        super(submission_id)
        upload_data = upload_data.first if upload_data.is_a?(Array) # temporary for transition
        guid = upload_data&.dig('confirmationCode')
        with_tracking("Form526 Upload: #{guid}", submission.saved_claim_id, submission.id) do
          sea = SupportingEvidenceAttachment.find_by(guid:)
          file_body = sea&.get_file&.read

          raise ArgumentError, "supporting evidence attachment with guid #{guid} has no file data" if file_body.nil?

          document_data = create_document_data(upload_data, sea.converted_filename)
          raise Common::Exceptions::ValidationErrors, document_data unless document_data.valid?

          if Flipper.enabled?(:disability_compensation_use_api_provider_for_submit_veteran_upload)
            upload_via_api_provider(submission, upload_data, file_body, sea)
          else
            EVSS::DocumentsService.new(submission.auth_headers).upload(file_body, document_data)
          end
        end
      rescue => e
        # Can't send a job manually to the dead set.
        # Log and re-raise so the job ends up in the dead set and the parent batch is not marked as complete.
        retryable_error_handler(e)
      end

      private

      # Will upload the document via a SupplementalDocumentUploadProvider
      # We use these providers to iteratively migrate uploads to Lighthouse
      #
      # @param submission [Form526Submission]
      # @param upload_data [Hash] the form metadata for the attachment
      # @param file_body [string] Attachment file contents
      # @param attachment [SupportingEvidenceAttachment] Upload attachment record
      def upload_via_api_provider(submission, upload_data, file_body, attachment)
        document_type = upload_data['attachmentId']
        provider = self.class.api_upload_provider(submission, document_type, attachment)

        # Fall back to name in metadata if converted_filename returns nil; matches existing behavior
        filename = attachment.converted_filename || upload_data['name']

        upload_document = provider.generate_upload_document(filename)
        provider.submit_upload_document(upload_document, file_body)
      end

      def retryable_error_handler(error)
        super(error)
        raise error
      end

      def create_document_data(upload_data, converted_filename)
        EVSSClaimDocument.new(
          evss_claim_id: submission.submitted_claim_id,
          file_name: converted_filename || upload_data['name'],
          tracked_item_id: nil,
          document_type: upload_data['attachmentId']
        )
      end
    end
  end
end
