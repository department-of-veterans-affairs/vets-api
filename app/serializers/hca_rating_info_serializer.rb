# frozen_string_literal: true

class HCARatingInfoSerializer
  include JSONAPI::Serializer

  set_id { '' }

  attribute :user_percent_of_disability do |object|
    object[:user_percent_of_disability].to_i
  end
end
