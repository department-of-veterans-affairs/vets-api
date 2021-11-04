# frozen_string_literal: true

module TestUserDashboard
  class DailyMaintenance
    include Sidekiq::Worker

    TUD_ACCOUNTS_TABLE = 'tud_accounts'

    def perform
      checkin_tud_accounts
      mirror_tud_accounts_in_bigquery
    end

    private

    def checkin_tud_accounts
      TestUserDashboard::TudAccount.where.not(checkout_time: nil).each do |account|
        account.update(checkout_time: nil)

        TestUserDashboard::AccountMetrics
          .new(account)
          .checkin(checkin_time: Time.now.getlocal, maintenance_update: true)
      end
    end

    def mirror_tud_accounts_in_bigquery
      client = TestUserDashboard::BigQuery.new
      client.drop(table_name: TUD_ACCOUNTS_TABLE)
      client.create(table_name: TUD_ACCOUNTS_TABLE, rows: all_tud_accounts_as_objects)
    end

    def all_tud_accounts_as_objects
      TestUserDashboard::TudAccount.all.each.with_object([]) do |account, rows|
        rows << account.attributes.reject { |attr, _| %w[id password].include?(attr) }
      end
    end
  end
end
