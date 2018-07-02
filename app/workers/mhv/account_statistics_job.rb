# frozen_string_literal: true

module MHV
  class AccountStatisticsJob
    include Sidekiq::Worker

    sidekiq_options retry: false

    def perform
      stats = { accounts_created_count: MhvAccount.accounts_created.count,
                existing_accounts_upgraded_count: MhvAccount.existing_accounts_upgraded.count,
                created_failed_upgrade_count: MhvAccount.created_failed_upgrade.count,
                created_and_upgraded_count: MhvAccount.created_and_upgraded.count,
                failed_create_count: MhvAccount.failed_create.count,
                total_mhv_account_count: MhvAccount.count }
      stats.each do |metric, count|
        StatsD.gauge(metric.to_s, count)
      end
      logger.info(mhv_account_statistics: stats)
    end
  end
end
