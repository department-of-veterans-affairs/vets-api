# frozen_string_literal: true

require 'sidekiq'

module Mobile
  module V0
    class Vet360LinkingJob
      include Sidekiq::Worker

      sidekiq_options(retry: false)

      def perform(current_user)
        Mobile::V0::Profile::SyncUpdateService.new(current_user).await_vet360_account_link
        Rails.logger.info('Mobile Vet360 account linking succeeded for user with uuid',
                          { user_uuid: current_user.account_uuid })
      rescue => e
        Rails.logger.error('Mobile Vet360 account linking failed for user with uuid',
                           { user_uuid: current_user.account_uuid, error: e })
      ensure
        redis = Redis::Namespace.new(REDIS_CONFIG[:mobile_vets360_account_link_lock][:namespace], redis: Redis.current)
        redis.del(current_user.account_uuid)
      end
    end
  end
end
