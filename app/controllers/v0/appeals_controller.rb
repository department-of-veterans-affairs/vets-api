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

    def show
      higher_level_review = HigherLevelReview.for_user(current_user).find_by(higher_level_review_id: params[:id])
      raise Common::Exceptions::RecordNotFound, params[:higher_level_review_id] unless higher_level_review

      higher_level_review, synchronized = service.update_from_remote(higher_level_review)
      render json: higher_level_review, serializer: HigherLevelReviewSerializer,
             meta: { successful_sync: synchronized }
    end

    def intake_status
      intake_status = service.intake_status
      render json: intake_status, serializer: IntakeStatusSerializer
    end

    private

    def service
      HigherLevelReview.new(current_user)
    end
  end
end
