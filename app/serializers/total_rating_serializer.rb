# frozen_string_literal: true

class TotalRatingSerializer < ActiveModel::Serializer
  attribute :rated_disabilities
  attribute :total_rating

  def id
    nil
  end
end
