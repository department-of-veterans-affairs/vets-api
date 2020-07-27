# frozen_string_literal: true

class AppealsApi::HigherLevelReviewSerializer < ActiveModel::Serializer
  attributes :status, :updated_at, :created_at, :form_data
end
