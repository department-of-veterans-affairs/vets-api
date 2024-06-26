# frozen_string_literal: true

class SponsorsSerializer
  include JSONAPI::Serializer

  attribute :sponsors

  set_id { '' }
end
