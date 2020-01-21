# frozen_string_literal: true

module V0
  class AppealsController < ApplicationController
    include ActionController::Serialization

    before_action { authorize :appeals, :access? }

    def index
      appeals_response = Appeals::Service.new.get_appeals(current_user)
      render(
        json: appeals_response.body
      )
    end

    def show_higher_level_review
      higher_level_review = review_service.get_higher_level_reviews(params[:uuid])
      render json: higher_level_review.body
    end

    def show_intake_status
      intake_status = review_service.get_higher_level_reviews_intake_status(params[:intake_id])
      render json: intake_status.body
    end

    def create_higher_level_review
      review = review_service.post_higher_level_reviews(request.raw_post)
      render status: review.status, json: review.body
    def show_contestable_issues
      issues = review_service.get_contestable_issues(current_user)
      render json: issues.body
    end

    private

    def review_service
      DecisionReview::Service.new
    end
  end
end
