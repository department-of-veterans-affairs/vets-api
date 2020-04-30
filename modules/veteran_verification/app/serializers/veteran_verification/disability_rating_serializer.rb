# frozen_string_literal: true

module VeteranVerification
  class DisabilityRatingSerializer < ActiveModel::Serializer
    attributes :overall_disability_rating, :ratings
    type 'disability_ratings'
  end
end
