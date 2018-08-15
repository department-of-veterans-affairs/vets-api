# frozen_string_literal: true

module MHV
  class AccountStatisticsJob
    include Sidekiq::Worker

    sidekiq_options retry: false

    def perform
      stats = { 'mhv.account.created_count' => MhvAccount.historic.created.count,
                'mhv.account.existing_premium_count' => MhvAccount.historic.existing_premium.count,
                'mhv.account.existing_upgraded_count' => MhvAccount.historic.existing_upgraded.count,
                'mhv.account.created_failed_upgrade_count' => MhvAccount.historic.created_failed_upgrade.count,
                'mhv.account.created_and_upgraded_count' => MhvAccount.historic.created_and_upgraded.count,
                'mhv.account.failed_create_count' => MhvAccount.historic.failed_create.count,
                'mhv.account.total_count' => MhvAccount.historic.count,
                'mhv.account.active.created_count' => MhvAccount.active.created.count,
                'mhv.account.active.existing_premium_count' => MhvAccount.active.existing_premium.count,
                'mhv.account.active.existing_upgraded_count' => MhvAccount.active.existing_upgraded.count,
                'mhv.account.active.created_failed_upgrade_count' => MhvAccount.active.created_failed_upgrade.count,
                'mhv.account.active.created_and_upgraded_count' => MhvAccount.active.created_and_upgraded.count,
                'mhv.account.active.failed_create_count' => MhvAccount.active.failed_create.count,
                'mhv.account.active.total_count' => MhvAccount.active.count }
      stats.each do |metric, count|
        StatsD.gauge(metric, count)
      end
      logger.info(mhv_account_statistics: stats)
    end
  end
end
