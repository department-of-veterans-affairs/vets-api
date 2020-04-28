# frozen_string_literal: true

module VeteranVerification
  class TotalDisabilityRatingSerializer < ActiveModel::Serializer
    attributes :disability_rating_record
    type 'disability_ratings'
  end
end

