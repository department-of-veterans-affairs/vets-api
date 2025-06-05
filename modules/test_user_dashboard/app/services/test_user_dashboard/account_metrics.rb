# frozen_string_literal: true

module TestUserDashboard
  class AccountMetrics
    attr_reader :tud_account, :availability_log

    def initialize(user)
      @tud_account = TudAccount.find_by(user_account_id: user.user_account_id)
      @availability_log = last_tud_account_availability_log
    end

    def checkin(is_manual_checkin: false)
      return unless tud_account

      availability_log.update(checkin_time: Time.now.utc, is_manual_checkin:) if last_checkin_time_nil?
    end

    def checkout
      return unless tud_account

      availability_log.update(has_checkin_error: true) if last_checkin_time_nil?

      TestUserDashboard::TudAccountAvailabilityLog.create(
        user_account_id: tud_account.user_account_id,
        checkout_time: Time.now.utc
      )
    end

    private

    def last_tud_account_availability_log
      TestUserDashboard::TudAccountAvailabilityLog.where(user_account_id: tud_account.user_account_id).last if tud_account
    end

    def last_checkin_time_nil?
      availability_log.present? && availability_log.checkin_time.nil?
    end
  end
end
