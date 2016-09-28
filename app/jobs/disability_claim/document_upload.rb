# frozen_string_literal: true
class DisabilityClaim::DocumentUpload < ActiveJob::Base
  def perform(filename, user_attrs, claim_id, tracked_item_id)
    user = User.new(user_attrs)
    client = EVSS::DocumentsService.new(user)
    uploader = DisabilityClaimDocumentUploader.new
    uploader.retrieve_from_store!(filename)
    client.upload(filename, uploader.read, claim_id, tracked_item_id)
    uploader.remove!
  end
end
