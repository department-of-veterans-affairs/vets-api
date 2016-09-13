# frozen_string_literal: true
require_dependency 'evss/base_service'

module EVSS
  class DocumentsService < BaseService
    def initialize(vaafi_headers = {})
      super()
      # TODO: Get base URI from env
      @base_url = 'http://csraciapp6.evss.srarad.com:7003/wss-document-services-web-3.1/rest/'
      @headers = vaafi_headers
    end

    def all_documents
      get 'documents/getAllDocuments'
    end

    def upload(file_name, file_body, claim_id, tracked_item_id)
      post 'queuedDocumentUploadService/ajaxUploadFile', file_body do |req|
        req.headers['Content-Type'] = 'application/octet-stream'
        req.params['systemName'] = SYSTEM_NAME
        # TODO: Get real doctypes/descriptions
        req.params['docType'] = 'L023'
        req.params['docTypeDescription'] = 'Other Correspondence'
        req.params['claimId'] = claim_id
        # In theory one document can correspond to multiple tracked items
        # To do that, add multiple query parameters
        req.params['trackedItemIds'] = tracked_item_id
        req.params['qqfile'] = file_name
      end
    end
  end
end
