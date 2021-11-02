# frozen_string_literal: true

module TestUserDashboard
  class AccountMetrics
    TABLE = 'tud_account_events'

    attr_reader :tud_account

    def initialize(user)
      @tud_account = TudAccount.find_by(account_uuid: user.account_uuid)
    end

    def checkin(checkin_time:)
      return unless tud_account

      row = {
        event: 'checkin',
        uuid: tud_account.account_uuid,
        timestamp: checkin_time
      }

      TestUserDashboard::BigQuery.new.insert_into(table: TABLE, rows: [row])
    end

    def checkout
      return unless tud_account

      row = {
        event: 'checkout',
        uuid: tud_account.account_uuid,
        timestamp: tud_account.checkout_time
      }

      TestUserDashboard::BigQuery.new.insert_into(table: TABLE, rows: [row])
    end
  end
end
