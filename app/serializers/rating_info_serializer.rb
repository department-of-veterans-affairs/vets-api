# frozen_string_literal: true

class RatingInfoSerializer < ActiveModel::Serializer
  # attribute :rating_info
  attribute :user_percent_of_disability

  def id
    nil
  end
end
