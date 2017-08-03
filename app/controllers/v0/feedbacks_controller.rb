# frozen_string_literal: true
module V0
  class FeedbacksController < ApplicationController
    include ActionController::ParamsWrapper
    wrap_parameters Feedback, format: :json

    skip_before_action :authenticate

    # POST /v0/feedback
    def create
      byebug
      feedback = Feedback.new(feedback_params)
      # TODO : make service call
      render json: {}, status: :created
      # Parse params
      # Make Github API call
      # Respond with 201
    end

    def feedback_params
      params.require(:feedback).permit(:target_page, :owner_email, :description)
    end
  end
end