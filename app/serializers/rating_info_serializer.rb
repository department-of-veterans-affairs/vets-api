# frozen_string_literal: true

class RatingInfoSerializer
  include JSONAPI::Serializer

  set_id { '' }

  attribute :user_percent_of_disability do |object|
    object.user_percent_of_disability
  end

  attribute :source_system do |_|
    'EVSS'
  end
end
