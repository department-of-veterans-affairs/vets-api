# frozen_string_literal: true

class EVSS::DocumentUpload
  include Sidekiq::Worker

  # retry for one day
  sidekiq_options retry: 14

  def perform(auth_headers, user_uuid, document_hash)
    document = EVSSClaimDocument.new document_hash
    client = EVSS::DocumentsService.new(auth_headers)
    uploader = EVSSClaimDocumentUploader.new(user_uuid, document.uploader_ids)
    uploader.retrieve_from_store!(document.file_name)
    file_body = uploader.read_for_upload
    client.upload(file_body, document)
    uploader.remove!
  end
end
