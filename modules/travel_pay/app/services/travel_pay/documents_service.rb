# frozen_string_literal: true

module TravelPay
  class DocumentsService
    def initialize(auth_manager)
      @auth_manager = auth_manager
    end

    def get_document_summaries(claim_id)
      @auth_manager.authorize => { veis_token:, btsss_token: }
      documents_response = client.get_document_ids(veis_token, btsss_token, claim_id)
      documents_response.body['data']
    end

    def download_document(claim_id, doc_id)
      unless claim_id.present? && doc_id.present?
        raise ArgumentError,
              message: "Missing claim ID or document ID, given: claim_id=#{claim_id}, doc_id=#{doc_id}"
      end

      params = { claim_id:, doc_id: }
      @auth_manager.authorize => { veis_token:, btsss_token: }

      response = client.get_document_binary(veis_token, btsss_token, params)

      {
        body: response.body,
        disposition: response.headers['Content-Disposition'],
        type: response.headers['Content-Type'],
        content_length: response.headers['Content-Length'],
        filename: response.headers['Content-Disposition'][/filename="(.+?)"/, 1]
      }
    end

    def upload_document(claim_id, uploaded_document)
      unless claim_id.present? && uploaded_document.present?
        raise ArgumentError,
              message:
                "Missing Claim ID or Uploaded Document, given: claim_id=#{claim_id}, uploaded_doc=#{uploaded_document}"
      end

      params = { claim_id:, uploaded_doc: }
      @auth_manager.authorize => { veis_token:, btsss_token: }

      documents_response = client.get_document_ids(veis_token, btsss_token, params)
      documents_response.body['data']
    end

    private

    def client
      TravelPay::DocumentsClient.new
    end
  end
end
