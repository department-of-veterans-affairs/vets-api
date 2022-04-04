# frozen_string_literal: true

require 'sidekiq'
require 'evss/documents_service'
require 'claims_api/claim_logger'

module ClaimsApi
  class ClaimUploader
    include Sidekiq::Worker

    sidekiq_options retry: true, unique_until: :success

    def perform(uuid)
      claim_object = ClaimsApi::SupportingDocument.find_by(id: uuid) ||
                     ClaimsApi::AutoEstablishedClaim.find_by(id: uuid)

      auto_claim = claim_object.try(:auto_established_claim) || claim_object

      if auto_claim.evss_id.nil?
        self.class.perform_in(30.minutes, uuid)
      else
        auth_headers = auto_claim.auth_headers
        uploader = claim_object.uploader
        uploader.retrieve_from_store!(claim_object.file_data['filename'])
        file_body = uploader.read
        ClaimsApi::Logger.log('526', claim_id: auto_claim.id, attachment_id: uuid)
        service(auth_headers).upload(file_body, claim_upload_document(claim_object))
      end
    end

    private

    def claim_upload_document(claim_document)
      upload_document = OpenStruct.new(
        file_name: claim_document.file_name,
        document_type: claim_document.document_type,
        description: claim_document.description
      )

      if claim_document.is_a? ClaimsApi::SupportingDocument
        upload_document.evss_claim_id = claim_document.evss_claim_id
        upload_document.tracked_item_id = claim_document.tracked_item_id
      else # then it's a ClaimsApi::AutoEstablishedClaim
        upload_document.evss_claim_id = claim_document.evss_id
        upload_document.tracked_item_id = claim_document.id
      end

      upload_document
    end

    def service(auth_headers)
      EVSS::DocumentsService.new(
        auth_headers
      )
    end
  end
end
