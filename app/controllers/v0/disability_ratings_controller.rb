# frozen_string_literal: true
module V0
  class DisabilityRatingsController < DisabilityClaimsController
    def show
      disability_rating = DisabilityRating.new(current_user.rating_record['disabilityRatingRecord'])
      render json: disability_rating,
             serializer: DisabilityRatingSerializer
    end
  end
end
