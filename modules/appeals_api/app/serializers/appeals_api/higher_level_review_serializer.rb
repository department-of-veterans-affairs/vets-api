# frozen_string_literal: true

module AppealsApi
  class HigherLevelReviewSerializer < ActiveModel::Serializer
    attribute :status
    attribute :updated_at
    attribute :created_at
    attribute :auth_headers
    attribute :form_data
    type :higher_level_review
  end
end
