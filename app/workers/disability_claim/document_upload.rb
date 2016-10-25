# frozen_string_literal: true
class DisabilityClaim::DocumentUpload
  include Sidekiq::Worker

  def perform(document_data, auth_headers, user_uuid)
    client = EVSS::DocumentsService.new(auth_headers)
    uploader = DisabilityClaimDocumentUploader.new(user_uuid, document_data.tracked_item_id)
    uploader.retrieve_from_store!(document_data.file_name)
    file_body = uploader.read
    client.upload(file_body, document_data)
    uploader.remove!
  end
end
