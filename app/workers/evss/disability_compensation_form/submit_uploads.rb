# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitUploads
      include Sidekiq::Worker
      include JobStatus

      RETRY = 10
      FORM_TYPE = '21-526EZ'
      STATSD_KEY_PREFIX = 'worker.evss.submit_form526_upload'

      sidekiq_options retry: RETRY

      def perform(auth_headers, evss_claim_id, saved_claim_id, submission_id, upload_data)
        guid = upload_data&.dig('confirmationCode')
        with_tracking("Form526 Upload: #{guid}", saved_claim_id, submission_id) do
          file_body = SupportingEvidenceAttachment.find_by(guid: guid)&.get_file&.read
          raise ArgumentError, "supporting evidence attachment with guid #{guid} has no file data" if file_body.nil?
          document_data = create_document_data(evss_claim_id, upload_data)
          client = EVSS::DocumentsService.new(auth_headers)
          client.upload(file_body, document_data)
        end
      end

      private

      def create_document_data(evss_claim_id, upload_data)
        EVSSClaimDocument.new(
          evss_claim_id: evss_claim_id,
          file_name: upload_data['name'],
          tracked_item_id: nil,
          document_type: upload_data['attachmentId']
        )
      end
    end
  end
end
