# frozen_string_literal: true

module VeteranVerification
  class DisabilityRatingSerializer < ActiveModel::Serializer
    attributes :combined_disability_rating, :combined_effective_date, :individual_ratings
    type 'disability_ratings'
  end
end
