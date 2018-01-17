# frozen_string_literal: true

require 'evss/base_service'

module EVSS
  class DocumentsService < BaseService
    API_VERSION = Settings.evss.versions.documents
    BASE_URL = "#{Settings.evss.url}/wss-document-services-web-#{API_VERSION}/rest/"
    # this service is only used from an async worker so long timeout is acceptable here
    DEFAULT_TIMEOUT = 180 # seconds

    def upload(file_body, document_data)
      headers = { 'Content-Type' => 'application/octet-stream' }
      post 'queuedDocumentUploadService/ajaxUploadFile', file_body, headers do |req|
        req.params['systemName'] = SYSTEM_NAME
        req.params['docType'] = document_data.document_type
        req.params['docTypeDescription'] = document_data.description
        req.params['claimId'] = document_data.evss_claim_id
        # In theory one document can correspond to multiple tracked items
        # To do that, add multiple query parameters
        req.params['trackedItemIds'] = document_data.tracked_item_id
        req.params['qqfile'] = document_data.file_name
      end
    end

    def self.breakers_service
      BaseService.create_breakers_service(name: 'EVSS/Documents', url: BASE_URL)
    end
  end
end
