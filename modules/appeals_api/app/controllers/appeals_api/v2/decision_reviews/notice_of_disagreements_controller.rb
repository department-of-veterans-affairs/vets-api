# frozen_string_literal: true

class AppealsApi::V2::DecisionReviews::NoticeOfDisagreementsController < AppealsApi::ApplicationController

  skip_before_action :authenticate
  before_action :not_implemented

  def create
  end

  def show
  end

  def validate
  end

  def schema
  end

  private

  def not_implemented
    render json: { message: 'V2 is not implemented yet' }, status: :not_implemented
  end
end
