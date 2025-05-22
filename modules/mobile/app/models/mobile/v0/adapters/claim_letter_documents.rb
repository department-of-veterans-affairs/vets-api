# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class ClaimLetterDocuments
        def self.parse(documents)
          documents.map do |document|
            # Backwards compatibility: the document ids that came from eFolder were wrapped in {} brackets
            # The Front End expects these as the ids are being compared to ids coming from GET claims that have {}'s
            document_id = document[:documentUuid]
            document_id = "{#{document_id}}" if document_id.first != '{' && document_id.last != '}'

            Mobile::V0::ClaimLetterDocument.new(
              id: document_id,
              doc_type: document[:docTypeId],
              type_description: document[:documentTypeLabel],
              received_at: document[:uploadedDateTime]
            )
          end
        end
      end
    end
  end
end
