# frozen_string_literal: true

class PreferredNameSerializer
  include JSONAPI::Serializer

  set_id { '' }
  attributes :preferred_name
end
