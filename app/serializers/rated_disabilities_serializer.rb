# frozen_string_literal: true

class RatedDisabilitiesSerializer
  include JSONAPI::Serializer

  set_id { '' }
  attribute :rated_disabilities
end
