# frozen_string_literal: true

require 'sidekiq'

module ClaimsApi
  class ClaimUploader
    include Sidekiq::Worker

    def perform(document_id)
      document = ClaimsApi::SupportingDocument.find_by(id: document_id) || ClaimsApi::AutoEstablishedClaim.pending?(document_id)
      auto_claim = document.try(:auto_established_claim) || document
      auth_headers = auto_claim.auth_headers
      uploader = document.uploader
      uploader.retrieve_from_store!(document.file_data['filename'])
      file_body = uploader.read
      service(auth_headers).upload(file_body, document)
      uploader.remove!
    end

    private

    def service(auth_headers)
      EVSS::DocumentsService.new(
        auth_headers
      )
    end
  end
end
