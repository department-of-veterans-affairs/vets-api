# frozen_string_literal: true

module V0
  class HigherLevelReviewsController < AppealsBaseController
    def show
      review = decision_review_service.get_higher_level_reviews(params[:id])
      render json: review.body
    end

    def create
      review = decision_review_service.post_higher_level_reviews(request.raw_post)
      render status: review.status, json: review.body
    end
  end
end
