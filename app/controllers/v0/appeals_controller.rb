# frozen_string_literal: true

module V0
  class AppealsController < ApplicationController
    include ActionController::Serialization

    before_action { authorize :appeals, :access? }
    before_action :set_uuid, only: [:show, :intake_status]

    def index
      appeals_response = Appeals::Service.new.get_appeals(current_user)
      render(
        json: appeals_response.body
      )
    end

    def show
      service.get_higher_level_reviews @uuid
      render json: higher_level_review
    end

    def intake_status
      intake_status = service.get_higher_level_reviews_intake_status @uuid
      render json: intake_status
    end

    private

    def set_uuid
      set_higher_level_review
      @uuid = @higher_level_review.uuid
    end

    def set_higher_level_review
      @higher_level_review = HigherLevelReview.for_user(current_user).find_by(higher_level_review_id: params[:id])
      raise Common::Exceptions::RecordNotFound, params[:higher_level_review_id] unless higher_level_review
    end

    def service
      DecisionReview::Service.new
    end
  end
end
