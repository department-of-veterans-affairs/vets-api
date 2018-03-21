# frozen_string_literal: true

module EVSS
  module Documents
    class Service < EVSS::Service
      HEADERS = { 'Content-Type' => 'application/octet-stream' }.freeze

      configuration EVSS::Documents::Configuration

      def upload(file_body, document_data)
        perform(
          :post,
          'queuedDocumentUploadService/ajaxUploadFile',
          file_body,
          HEADERS
        ) do |req|
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
    end
  end
end
