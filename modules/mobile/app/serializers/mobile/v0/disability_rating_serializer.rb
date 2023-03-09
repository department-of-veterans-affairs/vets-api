# frozen_string_literal: true

module Mobile
  module V0
    class DisabilityRatingSerializer
      include JSONAPI::Serializer

      set_type :disabilityRating
      attributes :combined_disability_rating, :individual_ratings
    end
  end
end
