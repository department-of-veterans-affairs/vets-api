# frozen_string_literal: true

module V0
  class UserActionsController < ApplicationController
    service_tag 'identity'

    before_action :set_query_date_range, only: [:index]

    def index
      page = params[:page].presence || 1
      per_page = params[:per_page].presence || 10
      subject_user_verification = current_user.user_verification

      q = UserAction.includes(:user_action_event).where(subject_user_verification:).ransack(params[:q])
      @user_actions = q.result.page(page.to_i).per_page(per_page.to_i)

      render json: UserActionSerializer.new(@user_actions, **serializer_options), status: :ok
    end

    private

    def set_query_date_range
      params[:q] ||= {}
      params[:q][:created_at_gteq] ||= 1.month.ago.beginning_of_day
      params[:q][:created_at_lteq] ||= Time.zone.now.end_of_day
    end

    def links
      {
        first: url_for(page: 1, only_path: false),
        last: url_for(page: @user_actions.total_pages, only_path: false),
        prev: (url_for(page: @user_actions.previous_page, only_path: false) if @user_actions.previous_page),
        next: (url_for(page: @user_actions.next_page, only_path: false) if @user_actions.next_page)
      }.compact
    end

    def meta
      {
        current_page: @user_actions.current_page,
        total_pages: @user_actions.total_pages,
        per_page: @user_actions.per_page,
        total_count: @user_actions.count
      }
    end

    def serializer_options
      {
        is_collection: true,
        include: [:user_action_event],
        links:,
        meta:
      }
    end
  end
end
