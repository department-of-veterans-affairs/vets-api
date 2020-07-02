# frozen_string_literal: true

class AppealsApi::HigherLevelReviewSerializer
  include FastJsonapi::ObjectSerializer
  attributes :status, :updated_at, :created_at, :form_data
  set_type :higherLevelReviewInfo
end
