# frozen_string_literal: true

module ClaimsApi
  class ClaimDetailSerializer < EVSSClaimDetailSerializer
    include SerializerBase

    attribute :status
    attribute :supporting_documents

    def supporting_documents
      object.supporting_documents.map do |document|
        {
          id: document.id,
          type: 'claim_supporting_document',
          md5: Digest::MD5.hexdigest(document.form_data),
          filename: document.file_data[:filename],
          uploaded_at: document.created_at
        }
      end
    end
  end
end
