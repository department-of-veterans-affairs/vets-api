# frozen_string_literal: true

module V0
  class IntakeStatusesController < AppealsBaseController
    def show
      intake_status = decision_review_service.get_higher_level_reviews_intake_status(params[:id])
      render json: intake_status.body
    end
  end
end
