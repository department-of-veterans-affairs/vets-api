# frozen_string_literal: true

require 'sidekiq'

module ClaimsApi
  class ClaimUploader
    include Sidekiq::Worker

    def perform(supporting_document_id)
      supporting_document = ClaimsApi::SupportingDocument.find(supporting_document_id)
      auto_claim = supporting_document.auto_established_claim
      auth_headers = auto_claim.auth_headers
      uploader = supporting_document.uploader
      uploader.retrieve_from_store!(supporting_document.file_data['filename'])
      file_body = uploader.read
      
    #   document = EVSSClaimDocument.new document_hash
    # client = EVSS::DocumentsService.new(auth_headers)
    # uploader = EVSSClaimDocumentUploader.new(user_uuid, document.uploader_ids)
    # uploader.retrieve_from_store!(document.file_name)
    # file_body = uploader.read_for_upload
    # client.upload(file_body, document)

      response = service(auth_headers).upload(file_body, document_data)
      # uploader.remove!
    end

    private

    def service(auth_headers)
      EVSS::DocumentsService.new(
        auth_headers
      )
    end
  end
end
