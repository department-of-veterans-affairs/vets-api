# frozen_string_literal: true

module Mobile
  module V0
    class ClaimLetterDocumentsSerializer
      include JSONAPI::Serializer

      set_type :claim_letter_document
      attributes :doc_type,
                 :type_description,
                 :received_at
    end
  end
end
