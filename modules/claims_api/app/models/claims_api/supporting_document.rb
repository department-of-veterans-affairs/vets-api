# frozen_string_literal: true

require_dependency 'claims_api/json_marshal'

module ClaimsApi
  class SupportingDocument < ActiveRecord::Base
    attr_encrypted(:file_data, key: Settings.db_encryption_key, marshal: true, marshaler: ClaimsApi::JsonMarshal)

    belongs_to :auto_established_claim

    def set_file_data!(file_data)
      uploader = ClaimsApi::SupportingDocumentUploader.new(auto_established_claim.id)
      uploader.store!(file_data)
      self.file_data = { filename: uploader.filename }
    end
  end
end
