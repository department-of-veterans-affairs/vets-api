# frozen_string_literal: true

module Mobile
  module V0
    class CategorySerializer < ActiveModel::Serializer
      def id
        object.category_id
      end

      attribute(:message_category_type)
    end
  end
end
