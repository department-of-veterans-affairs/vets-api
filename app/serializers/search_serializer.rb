# frozen_string_literal: true

class SearchSerializer
  include JSONAPI::Serializer

  set_id { '' }

  attribute :body
end
