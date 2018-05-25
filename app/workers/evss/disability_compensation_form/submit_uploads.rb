# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitUploads
      include Sidekiq::Worker

      FORM_TYPE = '21-526EZ'
      DOCUMENT_TYPES = {
        5 => 'L049'
      }.freeze

      def self.start(uuid, auth_headers)
        batch = Sidekiq::Batch.new
        batch.on(
          :success,
          self,
          'uuid' => uuid
        )
        batch.jobs do
          claim_id = get_claim_id(uuid)
          uploads = get_uploads(uuid)
          # logger.info('submit uploads start', user: uuid, component: 'EVSS', \
          #             form: FORM_TYPE, upload_count: uploads.count)
          uploads.each_with_index do |upload_data, index|
            perform_async(upload_data, claim_id, auth_headers, uploads.count, index)
          end
        end
      end

      def perform(upload_data, claim_id, auth_headers)
        # logger.info('processing upload', user: uuid, component: 'EVSS', \
        #             form: FORM_TYPE, upload_count: count, upload_index: index)

        client = EVSS::DocumentsService.new(auth_headers)
        file_body = AncillaryFormAttachment.find_by(guid: guid).file_data
        document_data = EVSSClaimDocument.new(
          evss_claim_id: claim_id,
          file_name: upload_data[:file_name],
          tracked_item_id: nil,
          document_type: DOCUMENT_TYPES[upload_data[:enum]]
        )
        client.upload(file_body, document_data)

        # logger.info('upload processed', user: uuid, component: 'EVSS', \
        #             form: FORM_TYPE, upload_count: count, upload_index: index)
      rescue StandardError => error
        # logger.error(
        #   'upload processing failed', user: uuid, component: 'EVSS', \
        #   form: FORM_TYPE, upload_count: count, upload_index: index, detail: error.message
        # )
        raise error
      end

      def on_success(_status, options)
        # logger.info('submit uploads success', user: uuid, component: 'EVSS', form: FORM_TYPE)
      end

      def self.get_claim_id(uuid)
        form_submission = ::DisabilityCompensationSubmission.find_by(user_uuid: uuid, form_type: FORM_TYPE)
        form_submission.claim_id
      end

      def self.get_uploads(uuid)
        user = User.find(uuid)
        InProgressDisabilityCompensationForm.form_for_user(FORM_TYPE, user).uploads
      end
    end
  end
end
