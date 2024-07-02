# frozen_string_literal: true

module Mobile
  module V0
    class CategorySerializer
      include JSONAPI::Serializer

      set_type :categories
      set_id(&:category_id)

      attribute :message_category_type
    end
  end
end
