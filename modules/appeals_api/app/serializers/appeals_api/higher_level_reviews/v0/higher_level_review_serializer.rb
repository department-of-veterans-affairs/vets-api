# frozen_string_literal: true

module AppealsApi::HigherLevelReviews::V0
  class HigherLevelReviewSerializer
    include JSONAPI::Serializer
    set_key_transform :camel_lower
    set_type :higherLevelReview
    attributes :status
    attribute :code, if: proc { |hlr| hlr.status == 'error' }
    attribute :detail, if: proc { |hlr| hlr.status == 'error' }
    # These names are required by Lighthouse standards
    attribute :createDate, &:created_at
    attribute :updateDate, &:updated_at
  end
end
