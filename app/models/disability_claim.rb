# frozen_string_literal: true
require_dependency 'evss/documents_service'

class DisabilityClaim < ActiveRecord::Base
  def self.upload_document(claim_id, file_name, file_body, tracked_item_id, user)
    # Todo, instead of having a class method and passing claim_id,
    # get claim_id from the model
    evss_client = EVSS::DocumentsService.new(user)
    evss_client.upload(file_name, file_body, claim_id, tracked_item_id).body
  end
end
