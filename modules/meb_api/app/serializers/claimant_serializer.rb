# frozen_string_literal: true

class ClaimantSerializer
  include JSONAPI::Serializer

  set_id { '' }

  attribute :claimant_id do |object|
    object.body[:claimant_id]
  end
end
