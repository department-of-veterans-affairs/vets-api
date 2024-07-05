# frozen_string_literal: true

module TestUserDashboard
  class TudAccountsController < ApplicationController
    include ActionView::Helpers::SanitizeHelper
    service_tag 'test-user-dashboard'
    before_action :require_jwt

    def index
      tud_accounts = TudAccount.all
      render json: TudAccountSerializer.new(tud_accounts)
    end

    def update
      tud_account = TudAccount.find(params[:id])
      sanitized_notes = sanitize params[:notes]
      tud_account.update!(notes: sanitized_notes)
      render json: TudAccountSerializer.new(tud_account)
    rescue ActiveRecord::RecordNotFound => e
      render json: { error: e }
    end
  end
end
