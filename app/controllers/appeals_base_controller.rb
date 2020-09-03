# frozen_string_literal: true

class AppealsBaseController < ApplicationController
  include ActionController::Serialization
  before_action { authorize :appeals, :access? }

  private

  def appeals_service
    Caseflow::Service.new
  end

  def decision_review_service
    DecisionReview::Service.new
  end
end
