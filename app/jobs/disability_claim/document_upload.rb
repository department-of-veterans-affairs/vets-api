# frozen_string_literal: true
class DisabilityClaim::DocumentUpload < ActiveJob::Base
  # TODO: (AJM) Pass in user once it can be serialized using GlobalID
  def perform(filename, claim_id, tracked_item_id)
    client = EVSS::DocumentsService.new(User.sample_claimant)
    uploader = DisabilityClaimDocumentUploader.new
    uploader.retrieve_from_store!(filename)
    client.upload(filename, uploader.read, claim_id, tracked_item_id)
    uploader.remove!
  end
end
