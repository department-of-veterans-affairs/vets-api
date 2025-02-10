# frozen_string_literal: true

module V0
  class UserActionEventsController < ApplicationController
    service_tag 'identity'

    def index
      user_verification = current_user.user_verification

      start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Time.zone.now
      end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Time.zone.today
      page = params[:page] || 1
      per_page = params[:per_page] || 10

      user_actions = UserAction
                     .where(subject_user_verification_id: user_verification.id)
                     .where(created_at: start_date..end_date)
                     .includes(:user_action_event)
                     .order(created_at: :desc)
                     .page(page)
                     .per_page(per_page)
      render json: UserActionSerializer.new(user_actions), include: [:user_action_event]
    end
  end
end
