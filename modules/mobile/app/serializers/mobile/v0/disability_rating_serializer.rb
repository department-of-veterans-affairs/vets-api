# frozen_string_literal: true

module Mobile
  module V0
    class DisabilityRatingSerializer
      include FastJsonapi::ObjectSerializer

      set_type :disabilityRating
      attributes :combined_disability_rating, :combined_effective_date, :legal_effective_date, :individual_ratings
    end
  end
end
