# frozen_string_literal: true

class AppealsApi::HigherLevelReviewSerializer
  include JSONAPI::Serializer
  set_key_transform :camel_lower
  attributes :status, :updated_at, :created_at
  # only return form_data for created records
  attribute :form_data, if: proc { |record| record.saved_change_to_id? }
  set_type :higherLevelReview
end
