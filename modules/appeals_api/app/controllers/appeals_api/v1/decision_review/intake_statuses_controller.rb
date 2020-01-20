# frozen_string_literal: true

class AppealsApi::V1::DecisionReview::IntakeStatusesController < AppealsApi::ApplicationController
  skip_before_action(:authenticate)

  def show
    render_response(Appeals::Service.new.get_intake_status(params[:id]))
  end
end
