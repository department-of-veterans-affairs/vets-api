# frozen_string_literal: true

module ClaimsApi
  class ClaimDetailSerializer < EVSSClaimDetailSerializer
    include SerializerBase

    attribute :status
    attribute :supporting_documents
    type :claims_api_claim

    def supporting_documents
      object.supporting_documents.map do |document|
        {
          id: document[:id],
          type: 'claim_supporting_document',
          md5: document[:md5],
          filename: document[:filename],
          uploaded_at: document[:uploaded_at]
        }
      end
    end
  end
end
