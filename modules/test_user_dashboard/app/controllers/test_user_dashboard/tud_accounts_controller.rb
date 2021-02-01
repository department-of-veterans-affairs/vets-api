# frozen_string_literal: true

require_dependency 'test_user_dashboard/application_controller'

module TestUserDashboard
  class TudAccountsController < ApplicationController
    def index
      @tud_accounts = TudAccount.where(nil)
      @tud_accounts = @tud_accounts.filter_by_first_name(params[:first_name]) if params[:first_name].present?
      @tud_accounts = @tud_accounts.filter_by_last_name(params[:last_name]) if params[:last_name].present?
      @tud_accounts = @tud_accounts.filter_by_email(params[:email]) if params[:email].present?
      @tud_accounts = @tud_accounts.filter_by_gender(params[:gender]) if params[:gender].present?
      @tud_accounts = @tud_accounts.filter_by_available(params[:available]) if params[:available].present?

      # tud_accounts = TudAccount.all
      render json: @tud_accounts
    end
  end
end
