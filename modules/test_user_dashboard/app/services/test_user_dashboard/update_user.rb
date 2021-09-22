# frozen_string_literal: true

module TestUserDashboard
  class UpdateUser
    attr_accessor :tud_account, :user

    def initialize(user)
      @user = user
      @tud_account = TudAccount.find_by(account_uuid: user.account_uuid)
    end

    def call(time = nil)
      return unless tud_account

      user_values = tud_account.user_values(user).merge(checkout_time: time)
      tud_account.update!(user_values)
    end
  end
end
