# frozen_string_literal: true

class EVSS::NewDocumentUpload
  include Sidekiq::Worker

  def perform(user_uuid, document_hash)
    document = EVSSClaimDocument.new(document_hash)
    client = EVSS::Documents::Service.new(User.find(user_uuid))
    uploader = EVSSClaimDocumentUploader.new(user_uuid, document.tracked_item_id)
    uploader.retrieve_from_store!(document.file_name)
    file_body = uploader.read_for_upload
    client.upload(file_body, document)
    uploader.remove!
  end
end
