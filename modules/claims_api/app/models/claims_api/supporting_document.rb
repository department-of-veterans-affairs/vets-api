# frozen_string_literal: true

module ClaimsApi
  class SupportingDocument < ApplicationRecord
    include FileData

    belongs_to :auto_established_claim
    validates :auto_established_claim_id, presence: true

    alias_attribute :tracked_item_id, :id

    def evss_claim_id
      auto_established_claim.evss_id
    end

    def uploader
      @uploader ||= ClaimsApi::SupportingDocumentUploader.new(auto_established_claim.id)
    end
  end
end
