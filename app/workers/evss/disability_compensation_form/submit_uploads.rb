# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitUploads < Job
      RETRY = 5
      FORM_TYPE = '21-526EZ'
      STATSD_KEY_PREFIX = 'worker.evss.submit_form526_upload'

      sidekiq_options retry: RETRY

      def perform(submission_id, upload_data)
        super(submission_id)
        guid = upload_data&.dig('confirmationCode')
        with_tracking("Form526 Upload: #{guid}") do
          file_body = SupportingEvidenceAttachment.find_by(guid: guid)&.get_file&.read
          raise ArgumentError, "supporting evidence attachment with guid #{guid} has no file data" if file_body.nil?
          document_data = create_document_data(upload_data)
          client = EVSS::DocumentsService.new(auth_headers)
          client.upload(file_body, document_data)
        end
      rescue StandardError => e
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
          evss_claim_id: submitted_claim_id,
          file_name: upload_data['name'],
          tracked_item_id: nil,
          document_type: upload_data['attachmentId']
        )
      end
    end
  end
end
