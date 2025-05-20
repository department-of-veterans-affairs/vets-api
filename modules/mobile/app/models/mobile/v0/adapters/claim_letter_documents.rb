# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class ClaimLetterDocuments
        def self.parse(documents)
          documents.map do |document|
            Mobile::V0::ClaimLetterDocuments.new(
              id: document[:documentUuid],
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
