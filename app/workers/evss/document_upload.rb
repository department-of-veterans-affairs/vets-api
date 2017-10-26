# frozen_string_literal: true
class EVSS::DocumentUpload
  include Sidekiq::Worker

  def perform(user_uuid, document_hash)
    user = User.find(user_uuid)
    document = EVSSClaimDocument.new document_hash
    client = EVSS::Documents::Service.new(user)
    uploader = EVSSClaimDocumentUploader.new(user_uuid, document.tracked_item_id)
    uploader.retrieve_from_store!(document.file_name)
    file_body = uploader.read_for_upload
    client.upload(file_body, document)
    uploader.remove!
  end
end
