# frozen_string_literal: true

module TestUserDashboard
  class CheckinUser
    attr_accessor :tud_account

    def initialize(account_uuid)
      @tud_account = TudAccount.find_by(account_uuid: account_uuid)
    end

    def call
      tud_account&.update!(checkout_time: nil)
    end
  end
end
