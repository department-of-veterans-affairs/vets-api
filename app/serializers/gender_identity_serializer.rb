# frozen_string_literal: true

class GenderIdentitySerializer
  include JSONAPI::Serializer

  set_id { '' }

  attribute :gender_identity
end
