# frozen_string_literal: true

class DisabilityContentionSerializer
  include JSONAPI::Serializer

  attribute :code
  attribute :medical_term
  attribute :lay_term
end
