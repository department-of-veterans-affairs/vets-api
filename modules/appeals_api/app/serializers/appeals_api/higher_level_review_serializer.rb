# frozen_string_literal: true

class AppealsApi::HigherLevelReviewSerializer
  include FastJsonapi::ObjectSerializer

  set_type 'HigherLevelReview'
  attributes :status, :updated_at, :created_at, :auth_headers, :form_data
end
