# frozen_string_literal: true

class TsaLetterSerializer
  include JSONAPI::Serializer

  set_id { '' }
  attribute :document_id, :doc_type, :type_description, :received_at
end
