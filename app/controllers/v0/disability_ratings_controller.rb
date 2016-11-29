# frozen_string_literal: true
module V0
  class DisabilityRatingsController < DisabilityClaimsBaseController
    def show
      disability_rating = claim_service.rating_info
      render json: disability_rating,
             serializer: DisabilityRatingSerializer
    end
  end
end
