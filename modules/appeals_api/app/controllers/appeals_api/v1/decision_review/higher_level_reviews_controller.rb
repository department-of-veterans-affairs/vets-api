# frozen_string_literal: true

class AppealsApi::V1::DecisionReview::HigherLevelReviewsController < AppealsApi::ApplicationController
  skip_before_action(:authenticate)

  def show
    render_response(Appeals::Service.new.get_higher_level_review(params[:id]))
  end

  def create
    render_response(Appeals::Service.new.create_higher_level_review(create_params))
  end

  private

  def create_params
    {
      'data' => params[:data].as_json,
      'included' => params[:included].as_json
    }
  end
end
