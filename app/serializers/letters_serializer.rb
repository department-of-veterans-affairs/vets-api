# frozen_string_literal: true

class LettersSerializer
  include JSONAPI::Serializer

  set_id { '' }

  attribute :letters
  attribute :full_name
end
