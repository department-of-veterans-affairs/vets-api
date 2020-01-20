# frozen_string_literal: true

class AppealsApi::V1::DecisionReview::HigherLevelReviewsController < AppealsApi::ApplicationController
  skip_before_action(:authenticate)

  def show
    render_response(Appeals::Service.new.get_higher_level_review(params[:id]))
  end
end
