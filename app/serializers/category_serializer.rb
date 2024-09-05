# frozen_string_literal: true

class CategorySerializer
  include JSONAPI::Serializer

  set_id :category_id
  set_type :categories

  attribute :message_category_type
end
