# frozen_string_literal: true

module V0
  class HigherLevelReviewsController < AppealsBaseController
    def show
      render json: decision_review_service.get_higher_level_review(params[:id]).body
    rescue => e
      log_exception_to_personal_information_log e, error_class: "#{self.class.name}#show exception", id: params[:id]
      raise
    end

    def create
      render json: decision_review_service
        .create_higher_level_review(request_body: request_body_hash, user: current_user)
        .body
    rescue => e
      request = begin
                  { body: request_body_hash }
                rescue
                  request_body_debug_data
                end

      log_exception_to_personal_information_log e, error_class: "#{self.class.name}#create exception", request: request
      raise
    end
  end
end
