# frozen_string_literal: true

module V0
  class UserActionEventsController < ApplicationController
    service_tag 'identity'

    def index
      user_verification = current_user.user_verification

      start_date = params[:start_date].present? ? Date.parse(params[:start_date]).beginning_of_day : 1.month.ago.to_date
      end_date = params[:end_date].present? ? Date.parse(params[:end_date]).end_of_day : Time.zone.now
      page = (params[:page].presence || 1).to_i
      per_page = (params[:per_page].presence || 10).to_i

      user_actions = UserAction
                     .where(subject_user_verification: user_verification)
                     .where(created_at: start_date..end_date)
                     .includes(:user_action_event)
                     .order(created_at: :desc)
                     .page(page)
                     .per_page(per_page)

      serialized_data = UserActionSerializer.new(user_actions, is_collection: true,
                                                               include: [:user_action_event]).serializable_hash

      render json: { data: serialized_data, meta: pagination_data(user_actions) }
    end

    private

    def pagination_data(user_actions)
      {
        current_page: user_actions.current_page,
        total_pages: user_actions.total_pages,
        per_page: user_actions.per_page,
        total_count: user_actions.count
      }
    end
  end
end
