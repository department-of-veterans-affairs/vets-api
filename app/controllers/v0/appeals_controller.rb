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
