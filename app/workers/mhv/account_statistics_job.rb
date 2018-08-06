# frozen_string_literal: true

module MHV
  class AccountStatisticsJob
    include Sidekiq::Worker

    sidekiq_options retry: false

    def perform
      stats = { 'mhv.account.created_count' => MhvAccount.created.count,
                'mhv.account.existing_premium_count' => MhvAccount.existing_premium.count,
                'mhv.account.existing_upgraded_count' => MhvAccount.existing_upgraded.count,
                'mhv.account.created_failed_upgrade_count' => MhvAccount.created_failed_upgrade.count,
                'mhv.account.created_and_upgraded_count' => MhvAccount.created_and_upgraded.count,
                'mhv.account.failed_create_count' => MhvAccount.failed_create.count,
                'mhv.account.total_count' => MhvAccount.count }
      stats.each do |metric, count|
        StatsD.gauge(metric, count)
      end
      logger.info(mhv_account_statistics: stats)
    end
  end
end
