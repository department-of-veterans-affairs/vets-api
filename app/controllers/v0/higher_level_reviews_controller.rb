# frozen_string_literal: true

module V0
  class HigherLevelReviewsController < AppealsBaseController
    def show
      render json: decision_review_service.get_higher_level_review(params[:id]).body
    end

    def create
      render json: decision_review_service
        .create_higher_level_review(request_body: JSON.parse(request.body.string), user: current_user)
        .body
    end
  end
end
