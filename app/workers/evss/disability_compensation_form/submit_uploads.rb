# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitUploads < Job
      STATSD_KEY_PREFIX = 'worker.evss.submit_form526_upload'

      # retry for one day
      sidekiq_options retry: 14

      # This callback cannot be tested due to the limitations of `Sidekiq::Testing.fake!`
      # :nocov:
      sidekiq_retries_exhausted do |msg, _ex|
        job_exhausted(msg, STATSD_KEY_PREFIX)
      end
      # :nocov:

      # Recursively submits a file in a new instance of this job for each upload in the uploads list
      #
      # @param submission_id [Integer] The {Form526Submission} id
      # @param upload_data [String] upload GUID in AWS S3
      #
      def perform(submission_id, upload_data)
        Raven.tags_context(source: '526EZ-all-claims')
        super(submission_id)
        upload_data = upload_data.first if upload_data.is_a?(Array) # temporary for transition
        guid = upload_data&.dig('confirmationCode')
        with_tracking("Form526 Upload: #{guid}", submission.saved_claim_id, submission.id) do
          sea = SupportingEvidenceAttachment.find_by(guid:)
          file_body = sea&.get_file&.read

          raise ArgumentError, "supporting evidence attachment with guid #{guid} has no file data" if file_body.nil?

          document_data = create_document_data(upload_data, sea.converted_filename)
          raise Common::Exceptions::ValidationErrors, document_data unless document_data.valid?

          client = EVSS::DocumentsService.new(submission.auth_headers)
          client.upload(file_body, document_data)
        end
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
