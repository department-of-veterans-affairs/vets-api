# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class ClaimLetterDocuments
        def self.parse(documents)
          documents.map do |document|
            Mobile::V0::ClaimLetterDocuments.new(
              # Backwards compatibility: the document ids that came from eFolder were wrapped in {} braces
              # The Front End excepts these as the ids are being compared to ids coming from GET claims that have {}'s
              id: "{#{document[:documentUuid]}}",
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
