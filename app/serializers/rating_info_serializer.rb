# frozen_string_literal: true

class RatingInfoSerializer
  include JSONAPI::Serializer

  set_id { '' }

  attribute :user_percent_of_disability

  attribute :source_system do |_|
    'EVSS'
  end
end
