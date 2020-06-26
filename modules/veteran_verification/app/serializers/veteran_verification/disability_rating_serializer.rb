# frozen_string_literal: true

module VeteranVerification
  class DisabilityRatingSerializer < ActiveModel::Serializer
    attributes :combined_disability_rating, :individual_ratings
    type 'disability_ratings'
  end
end
