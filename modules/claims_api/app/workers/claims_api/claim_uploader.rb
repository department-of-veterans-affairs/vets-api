# frozen_string_literal: true

require 'sidekiq'
require 'evss/documents_service'

module ClaimsApi
  class ClaimUploader
    include Sidekiq::Worker

    sidekiq_options retry: true, unique_until: :success

    def perform(uuid)
      object = ClaimsApi::SupportingDocument.find_by(id: uuid) || ClaimsApi::AutoEstablishedClaim.find_by(id: uuid)
      auto_claim = object.try(:auto_established_claim) || object
      if auto_claim.evss_id.nil?
        self.class.perform_in(30.minutes, uuid)
      else
        auth_headers = auto_claim.auth_headers
        uploader = object.uploader
        uploader.retrieve_from_store!(object.file_data['filename'])
        file_body = uploader.read
        service(auth_headers).upload(file_body, object)
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
