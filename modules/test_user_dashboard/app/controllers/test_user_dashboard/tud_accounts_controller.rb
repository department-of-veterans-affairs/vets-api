# frozen_string_literal: true

module TestUserDashboard
  class TudAccountsController < ApplicationController
    include ActionView::Helpers::SanitizeHelper
    before_action :require_jwt

    def index
      tud_accounts = TudAccount.all
      render json: tud_accounts
    end

    def update
      tud_account = TudAccount.find(params[:id])
      sanitized_notes = sanitize params[:notes]
      tud_account.update!(notes: sanitized_notes)
      render json: tud_account
    rescue ActiveRecord::RecordNotFound => e
      render json: { error: e }
    end
  end
end
