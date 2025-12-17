# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class ParticipantDocuments
        def self.parse(documents)
          return [] if documents.empty?

          documents.map do |document|
            Mobile::V0::ClaimLetterDocument.new(
              id: document['documentUuid'],
              doc_type: document['docTypeId'].to_s,
              type_description: document['documentTypeLabel'],
              received_at: document['receivedAt']
            )
          end
        end
      end
    end
  end
end
