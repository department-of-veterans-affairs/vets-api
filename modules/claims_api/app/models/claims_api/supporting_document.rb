# frozen_string_literal: true

require_dependency 'claims_api/json_marshal'

module ClaimsApi
  class SupportingDocument < ActiveRecord::Base
    attr_encrypted(:file_data, key: Settings.db_encryption_key, marshal: true, marshaler: ClaimsApi::JsonMarshal)

    belongs_to :auto_established_claim

    alias_attribute :tracked_item_id, :id

    def evss_claim_id
      auto_established_claim.evss_id
    end

    def set_file_data!(file_data)
      uploader.store!(file_data)
      self.file_data = { filename: uploader.filename }
    end

    def uploader
      @uploader ||= ClaimsApi::SupportingDocumentUploader.new(auto_established_claim.id)
    end
  end
end
