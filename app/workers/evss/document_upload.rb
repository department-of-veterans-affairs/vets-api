# frozen_string_literal: true

class EVSS::DocumentUpload
  include Sidekiq::Worker

  def perform(auth_headers, user_uuid, document_hash)
    Sentry::TagRainbows.tag
    document = EVSSClaimDocument.new document_hash
    client = EVSS::DocumentsService.new(auth_headers)
    uploader = EVSSClaimDocumentUploader.new(user_uuid, document.tracked_item_id)
    uploader.retrieve_from_store!(document.file_name)
    file_body = uploader.read_for_upload
    client.upload(file_body, document)
    uploader.remove!
  end
end
