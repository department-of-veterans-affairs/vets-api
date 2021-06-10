# frozen_string_literal: true

module TestUserDashboard
  class CheckoutUser
    attr_accessor :tud_account

    def initialize(account_uuid)
      @tud_account = TudAccount.find_by(account_uuid: account_uuid)
    end

    def call
      tud_account&.update!(checkout_time: Time.current)
    end
  end
end
