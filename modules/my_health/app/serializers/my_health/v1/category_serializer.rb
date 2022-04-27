# frozen_string_literal: true

module MyHealth
  module V1
    class CategorySerializer < ActiveModel::Serializer
      def id
        object.category_id
      end

      attribute(:message_category_type)
    end
  end
end
