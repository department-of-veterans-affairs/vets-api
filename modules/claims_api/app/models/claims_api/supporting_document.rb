# frozen_string_literal: true

require_dependency 'claims_api/json_marshal'

module ClaimsApi
  class SupportingDocument < ApplicationRecord
    attr_encrypted(:file_data, key: Settings.db_encryption_key, marshal: true, marshaler: ClaimsApi::JsonMarshal)

    belongs_to :auto_established_claim
    validates :auto_established_claim_id, presence: true

    alias_attribute :tracked_item_id, :id

    def evss_claim_id
      auto_established_claim.evss_id
    end

    def file_name
      file_data['filename']
    end

    def document_type
      file_data['doc_type']
    end

    def description
      file_data['description']
    end

    def set_file_data!(file_data, doc_type, description)
      uploader.store!(file_data)
      self.file_data = { filename: uploader.filename,
                         doc_type: doc_type,
                         description: description }
    end

    def uploader
      @uploader ||= ClaimsApi::SupportingDocumentUploader.new(auto_established_claim.id)
    end
  end
end
