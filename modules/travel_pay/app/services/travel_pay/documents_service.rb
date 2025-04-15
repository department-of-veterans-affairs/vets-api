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
      raise ArgumentError, message: "Missing claim ID or document ID, given: #{params}" unless claim_id && doc_id

      params = { claim_id:, doc_id: }
      @auth_manager.authorize => { veis_token:, btsss_token: }
      client.get_document_binary(veis_token, btsss_token, params)
    end

    private

    def client
      TravelPay::DocumentsClient.new
    end
  end
end
