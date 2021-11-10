# frozen_string_literal: true

module TestUserDashboard
  class DailyMaintenance
    include Sidekiq::Worker

    TUD_ACCOUNTS_TABLE = 'tud_accounts'

    def perform
      checkin_tud_accounts
    end

    private

    def checkin_tud_accounts
      TestUserDashboard::TudAccount.where.not(checkout_time: nil).each do |account|
        account.update(checkout_time: nil)

        TestUserDashboard::AccountMetrics
          .new(account)
          .checkin(checkin_time: Time.current, maintenance_update: true)
      end
    end
  end
end
