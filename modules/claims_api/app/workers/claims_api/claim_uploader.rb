# frozen_string_literal: true

require 'sidekiq'

module ClaimsApi
  class ClaimUploader
    include Sidekiq::Worker

    def perform(uuid)
      document = ClaimsApi::SupportingDocument.find_by(id: uuid) || ClaimsApi::AutoEstablishedClaim.pending?(uuid)
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
