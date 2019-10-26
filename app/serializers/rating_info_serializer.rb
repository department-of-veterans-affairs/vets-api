# frozen_string_literal: true

class RatingInfoSerializer < ActiveModel::Serializer
  attribute :rating_info

  def id
    nil
  end
end
