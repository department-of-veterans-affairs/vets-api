# frozen_string_literal: true

module TravelPay
  class DocumentsService < TravelPay::BaseClient
    def initialize(auth_manager)
      # NOTE: calling `super` without parentheses calls the super's initialize and passes the sub's arguments
      super()
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
              message: "Missing claim ID or document ID, given: #{params}"
      end

      params = { claim_id:, doc_id: }
      @auth_manager.authorize => { veis_token:, btsss_token: }

      response = client.get_document_binary(veis_token, btsss_token, params)
      response.body['data']
    end

    private

    def client
      TravelPay::DocumentsClient.new
    end
  end
end
