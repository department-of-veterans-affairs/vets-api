# frozen_string_literal: true

module TestUserDashboard
  class TrackAccountStatusesInBigQuery
    include Sidekiq::Worker

    TUD_ACCOUNT_STATUSES_TABLE = 'tud_account_statuses'

    def perform
      post_statuses_to_bigquery
    end

    private

    def post_statuses_to_bigquery
      client = TestUserDashboard::BigQuery.new
      client.insert_into(table_name: TUD_ACCOUNT_STATUSES_TABLE, rows: statuses)
    end

    def statuses
      TestUserDashboard::TudAccount.all.each.with_object([]) do |account, rows|
        row = {
          account_uuid: account.account_uuid,
          checked_out: account.checkout_time.nil? ? false : true,
          created_at: Time.now.utc
        }

        rows << row
      end
    end
  end
end
