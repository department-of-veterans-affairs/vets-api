# frozen_string_literal: true

module V0
  class FeedbacksController < ApplicationController
    include SentryLogging
    include ActionController::ParamsWrapper
    wrap_parameters Feedback, format: :json

    skip_before_action :authenticate

    # POST /v0/feedback
    def create
      feedback = Feedback.new(feedback_params)
      respond_400(feedback) unless feedback.valid?

      id = Github::CreateIssueJob.perform_async(feedback.attributes)

      render json: { job_id: id }, status: :accepted
    end

    private

    def feedback_params
      params.require(:feedback).permit(:target_page, :owner_email, :description)
    end

    def respond_400(feedback)
      missing_param = feedback.errors.messages.keys.first.to_s
      raise Common::Exceptions::ParameterMissing, missing_param
    end
  end
end
