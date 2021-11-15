# frozen_string_literal: true

module TestUserDashboard
  class MirrorAccountsInBigQuery
    include Sidekiq::Worker

    TUD_ACCOUNTS_TABLE = 'tud_accounts'

    def perform
      mirror_tud_accounts_in_bigquery
    end

    private

    def mirror_tud_accounts_in_bigquery
      client = TestUserDashboard::BigQuery.new
      client.delete_from(table_name: TUD_ACCOUNTS_TABLE)
      client.insert_into(table_name: TUD_ACCOUNTS_TABLE, rows: accounts)
    end

    def accounts
      TestUserDashboard::TudAccount.all.each.with_object([]) do |account, rows|
        rows << account.attributes.reject { |attr, _| %w[id password].include?(attr) }
      end
    end
  end
end
