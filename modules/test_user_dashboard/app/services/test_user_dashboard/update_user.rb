# frozen_string_literal: true

require 'sentry_logging'

module TestUserDashboard
  class UpdateUser
    include SentryLogging

    attr_accessor :tud_account, :user

    def initialize(user)
      @user = user
      @tud_account = TudAccount.find_by(account_uuid: user.account_uuid)
    end

    def call(time = nil)
      return unless tud_account

      user_values = tud_account.user_values(user).merge(checkout_time: time)
      valid_update = tud_account.update(user_values)
      log_message_to_sentry('[TestUserDashboard] UpdateUser invalid update', :warn, user_values) unless valid_update
    end
  end
end
