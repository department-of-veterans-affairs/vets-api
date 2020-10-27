# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitUploads < Job
      FORM_TYPE = '21-526EZ'
      STATSD_KEY_PREFIX = 'worker.evss.submit_form526_upload'

      # retry for one day
      sidekiq_options retry: 14

      # Recursively submits a file in a new instance of this job for each upload in the uploads list
      #
      # @param submission_id [Integer] The {Form526Submission} id
      # @param uploads [Array<String>] A list of the upload GUIDs in AWS S3
      #
      def perform(submission_id, uploads)
        super(submission_id)
        upload_data = uploads.shift
        guid = upload_data&.dig('confirmationCode')
        with_tracking("Form526 Upload: #{guid}", submission.saved_claim_id, submission.id) do
          file_body = SupportingEvidenceAttachment.find_by(guid: guid)&.get_file&.read
          raise ArgumentError, "supporting evidence attachment with guid #{guid} has no file data" if file_body.nil?

          document_data = create_document_data(upload_data)
          client = EVSS::DocumentsService.new(submission.auth_headers)
          client.upload(file_body, document_data)
        end
        perform_next(submission_id, uploads) if uploads.present?
      rescue => e
        # Can't send a job manually to the dead set.
        # Log and re-raise so the job ends up in the dead set and the parent batch is not marked as complete.
        retryable_error_handler(e)
      end

      private

      def retryable_error_handler(error)
        super(error)
        raise error
      end

      def create_document_data(upload_data)
        EVSSClaimDocument.new(
          evss_claim_id: submission.submitted_claim_id,
          file_name: upload_data['name'],
          tracked_item_id: nil,
          document_type: upload_data['attachmentId']
        )
      end

      # Uploads need to be run sequentially as per requested from EVSS
      # :nocov:
      def perform_next(id, uploads)
        batch.jobs do
          next_job = Sidekiq::Batch.new
          next_job.jobs do
            EVSS::DisabilityCompensationForm::SubmitUploads.perform_async(id, uploads)
          end
        end
      end
      # :nocov:
    end
  end
end
