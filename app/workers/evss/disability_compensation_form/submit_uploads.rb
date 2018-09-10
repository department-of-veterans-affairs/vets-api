# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitUploads
      include Sidekiq::Worker
      sidekiq_options dead: false

      FORM_TYPE = '21-526EZ'

      def self.start(user_uuid, auth_headers, claim_id, uploads)
        batch = Sidekiq::Batch.new
        batch.on(
          :success,
          self,
          'uuid' => user_uuid
        )
        batch.jobs do
          uploads.each do |upload_data|
            perform_async(upload_data, claim_id, auth_headers)
          end
        end
      end

      def perform(upload_data, claim_id, auth_headers)
        client = EVSS::DocumentsService.new(auth_headers)
        file_body = SupportingEvidenceAttachment.find_by(guid: upload_data[:confirmationCode]).file_data
        document_data = EVSSClaimDocument.new(
          evss_claim_id: claim_id,
          file_name: upload_data[:name],
          tracked_item_id: nil,
          document_type: upload_data[:attachmentId]
        )
        client.upload(file_body, document_data)
      end
    end
  end
end
