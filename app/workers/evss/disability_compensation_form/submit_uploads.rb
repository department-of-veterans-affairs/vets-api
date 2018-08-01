# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitUploads
      include Sidekiq::Worker

      FORM_TYPE = '21-526EZ'

      def self.start(user, claim_id, uploads)
        batch = Sidekiq::Batch.new
        batch.on(
          :success,
          self,
          'uuid' => user.uuid
        )
        batch.jobs do
          uploads.each do |upload_data|
            perform_async(upload_data, claim_id, user)
          end
        end
      end

      def self.perform(upload_data, claim_id, user)
        auth_headers = EVSS::AuthHeaders.new(user).to_h
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
