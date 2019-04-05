# frozen_string_literal: true

require 'sidekiq'

module ClaimsApi
  class ClaimUploader
    include Sidekiq::Worker

    def perform(supporting_document_id)
      supporting_document = ClaimsApi::SupportingDocument.find(supporting_document_id)
      auto_claim = supporting_document.auto_established_claim
      auth_headers = auto_claim.auth_headers
      
    #   document = EVSSClaimDocument.new document_hash
    # client = EVSS::DocumentsService.new(auth_headers)
    # uploader = EVSSClaimDocumentUploader.new(user_uuid, document.uploader_ids)
    # uploader.retrieve_from_store!(document.file_name)
    # file_body = uploader.read_for_upload
    # client.upload(file_body, document)
    # uploader.remove!

    #   auto_claim = ClaimsApi::AutoEstablishedClaim.find(auto_claim_id)

    #   form_data = auto_claim.form.to_internal
    #   auth_headers = auto_claim.auth_headers

      begin
        response = service(auth_headers).upload(file_body, document_data)
    #     auto_claim.evss_id = response.claim_id
    #     auto_claim.status = ClaimsApi::AutoEstablishedClaim::ESTABLISHED
    #     auto_claim.save
      rescue Common::Exceptions::BackendServiceException => e
    #     auto_claim.status = ClaimsApi::AutoEstablishedClaim::ERRORED
    #     auto_claim.save
    #     raise e
      end
    end

    private

    def service(auth_headers)
      EVSS::DocumentsService.new(
        auth_headers
      )
    end
  end
end
