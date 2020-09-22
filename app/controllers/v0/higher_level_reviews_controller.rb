# frozen_string_literal: true

module V0
  class HigherLevelReviewsController < AppealsBaseController
    before_action :render_error_unless_request_body_is_a_hash, only: [:create]

    def show
      render json: decision_review_service.get_higher_level_review(params[:id]).body
    end

    def create
      render json: decision_review_service
        .create_higher_level_review(request_body: request_body_hash, user: current_user)
        .body
    end
  end
end
