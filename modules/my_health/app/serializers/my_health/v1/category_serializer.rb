# frozen_string_literal: true

module MyHealth
  module V1
    class CategorySerializer
      include JSONAPI::Serializer

      set_type :categories
      set_id :category_id

      attribute :message_category_type
    end
  end
end
