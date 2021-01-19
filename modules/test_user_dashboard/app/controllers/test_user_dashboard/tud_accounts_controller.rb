# frozen_string_literal: true

require_dependency 'test_user_dashboard/application_controller'

module TestUserDashboard
  class TudAccountsController < ApplicationController
    def index
      tud_accounts = TudAccount.includes(:account)
      render(
        json: tud_accounts.to_json(include: [:account])
      )
    end
  end
end
