# frozen_string_literal: true

module AppealsApi
  class HigherLevelReviewSerializer < ActiveModel::Serializer
    attribute :status
    type :higher_level_review
  end
end
