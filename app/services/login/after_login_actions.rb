# frozen_string_literal: true

require 'login/errors'

module Login
  class AfterLoginActions
    include Accountable

    attr_reader :current_user

    def initialize(user)
      @current_user = user
    end

    def perform
      return unless current_user

      evss_create_account
      update_account_login_stats(login_type)

      if Settings.test_user_dashboard.env == 'staging'
        TestUserDashboard::UpdateUser.new(current_user).call(Time.current)
        TestUserDashboard::AccountMetrics.new(current_user).checkout
      end
    end

    private

    def login_type
      @login_type ||= current_user.identity.sign_in[:service_name]
    end

    def evss_create_account
      EVSS::CreateUserAccountJob.perform_async(current_user.uuid) if current_user.authorize(:evss, :access?)
    end
  end
end
