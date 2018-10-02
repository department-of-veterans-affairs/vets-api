# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitUploads
      include Sidekiq::Worker
      sidekiq_options dead: false

      FORM_TYPE = '21-526EZ'

      def self.start(user_uuid, auth_headers, evss_claim_id, saved_claim_id, uploads)
        batch = Sidekiq::Batch.new
        batch.jobs do
          uploads.each do |upload_data|
            perform_async(user_uuid, auth_headers, evss_claim_id, saved_claim_id, upload_data)
          end
        end
      end

      def perform(user_uuid, auth_headers, evss_claim_id, saved_claim_id, upload_data)
        client = EVSS::DocumentsService.new(auth_headers)
        guid = upload_data['confirmationCode']
        file_body = SupportingEvidenceAttachment.find_by(guid: guid)&.get_file&.read
        raise ArgumentError, "supporting evidence attachment with guid #{guid} has no file data" if file_body.nil?
        document_data = create_document_data(evss_claim_id, upload_data)

        client.upload(file_body, document_data)

        Rails.logger.info('Form526 Upload',
                          'user_uuid' => user_uuid,
                          'guid' => guid,
                          'saved_claim_id' => saved_claim_id,
                          'job_id' => jid,
                          'job_status' => 'received')
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
