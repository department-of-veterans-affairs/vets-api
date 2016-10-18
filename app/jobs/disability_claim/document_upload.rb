# frozen_string_literal: true
class DisabilityClaim::DocumentUpload < ActiveJob::Base
  def perform(filename, auth_headers, claim_id, tracked_item_id)
    client = EVSS::DocumentsService.new(auth_headers)
    uploader = DisabilityClaimDocumentUploader.new
    uploader.retrieve_from_store!(filename)
    client.upload(filename, uploader.read, claim_id, tracked_item_id)
    uploader.remove!
  end
end
