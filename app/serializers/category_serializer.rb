# frozen_string_literal: true

class CategorySerializer < ActiveModel::Serializer
  def id
    object.category_id
  end

  attribute(:message_category_type)
end
