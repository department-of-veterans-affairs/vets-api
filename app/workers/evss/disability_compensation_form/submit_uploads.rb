# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitUploads
      include Sidekiq::Worker

      DOCUMENT_TYPES = {
        5 => 'L049'
      }

      def self.start(uuid, auth_headers)
        batch = Sidekiq::Batch.new
        batch.on(
          :success,
          self,
          'uuid' => uuid,
        )
        batch.jobs do
          form_type = '21-526EZ'
          form_submission = ::DisabilityCompensationSubmission.find_by(user_uuid: uuid, form_type: form_type)
          user = User.find(uuid) #untested
          uploads = InProgressDisabilityCompensationForm.form_for_user(form_type, user).uploads
          uploads.each do |upload_data|
            perform_async(upload_data, form_submission.claim_id, auth_headers)
          end
        end
      end

      def perform(upload_data, claim_id, auth_headers)
        client = EVSS::DocumentsService.new(auth_headers)
        file_body = AncillaryFormAttachment.find_by(guid: guid).file_data #untested
        document_data = EVSSClaimDocument.new(
          evss_claim_id: claim_id,
          file_name: upload_data[:file_name],
          tracked_item_id: nil,
          document_type: DOCUMENT_TYPES[upload_data[:enum]]
        )
        client.upload(file_body, document_data) #untested
      end

      def on_success(status, options)
        puts 'SubmitUploads#on_success'
      end
    end
  end
end
