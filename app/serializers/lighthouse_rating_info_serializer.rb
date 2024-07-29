# frozen_string_literal: true

class LighthouseRatingInfoSerializer
  include JSONAPI::Serializer

  set_id { '' }

  attribute :user_percent_of_disability do |object|
    attr = :user_percent_of_disability
    object.respond_to?(attr) ? object.send(attr) : object[attr]
  end

  attribute :source_system do |_|
    'Lighthouse'
  end
end
