# frozen_string_literal: true

module MHV
  class AccountStatisticsJob
    include Sidekiq::Worker

    sidekiq_options retry: false

    def perform
      stats = { accounts_created_count: accounts_created.count,
                existing_accounts_upgraded_count: existing_accounts_upgraded.count,
                created_failed_upgrade_count: created_failed_upgrade.count,
                created_and_upgraded_count: created_and_upgraded.count }
      logger.info('mhv_account_statistics', stats)
    end

    private

    def accounts_created
      MhvAccount.where.not(registered_at: nil)
    end

    def existing_accounts_upgraded
      MhvAccount.where(registered_at: nil).where.not(upgraded_at: nil)
    end

    def created_failed_upgrade
      accounts_created.where(account_state: :upgrade_failed)
    end

    def created_and_upgraded
      accounts_created.where.not(upgraded_at: nil)
    end
  end
end
