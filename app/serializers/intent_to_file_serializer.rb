# frozen_string_literal: true

class IntentToFileSerializer
  include JSONAPI::Serializer

  set_id { '' }

  attribute :intent_to_file
end
