# frozen_string_literal: true

require_dependency 'test_user_dashboard/application_controller'

module TestUserDashboard
  class TudAccountsController < ApplicationController
    def index
      render(
        json: { 'key': 'value' }
      )
    end
  end
end
