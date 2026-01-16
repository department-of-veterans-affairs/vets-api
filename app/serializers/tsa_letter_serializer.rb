# frozen_string_literal: true

class TsaLetterSerializer
  include JSONAPI::Serializer

  set_id { '' }
  attribute :document_id, :document_version, :modified_datetime
end
