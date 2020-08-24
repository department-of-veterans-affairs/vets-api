# frozen_string_literal: true

module V0
  class HigherLevelReviewsController < AppealsBaseController
    def show
      review = decision_review_service.show_higher_level_review(params[:id])
      render json: review.body
    end

    def create
      review = decision_review_service
                 .create_higher_level_review(user: current_user, request_body: request.raw_post)
      render status: review.status, json: review.body
    end
  end
end
