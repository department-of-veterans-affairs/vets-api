# frozen_string_literal: true

module TestUserDashboard
  class MirrorAccountAvailabilityLogsInBigQuery
    include Sidekiq::Worker

    TUD_ACCOUNT_AVAILABILITY_LOGS = 'tud_account_availability_logs'

    def perform
      mirror_account_availability_logs_in_bigquery
    end

    private

    def mirror_account_availability_logs_in_bigquery
      client = TestUserDashboard::BigQuery.new
      client.delete_from(table_name: TUD_ACCOUNT_AVAILABILITY_LOGS)
      client.insert_into(table_name: TUD_ACCOUNT_AVAILABILITY_LOGS, rows: checkouts)
    end

    def checkouts
      TestUserDashboard::TudAccountAvailabilityLog.all.each.with_object([]) do |account, rows|
        rows << account.attributes.reject { |attr, _| attr == 'id' }
      end
    end
  end
end
