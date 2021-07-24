# frozen_string_literal: true

require 'sidekiq'

module Mobile
  module V0
    class Vet360LinkingJob
      include Sidekiq::Worker

      sidekiq_options(retry: false)

      def perform(uuid)
        user = IAMUser.find(uuid)
        result = Mobile::V0::Profile::SyncUpdateService.new(user).await_vet360_account_link
        Rails.logger.info('Mobile Vet360 account linking succeeded for user with uuid',
                          { user_uuid: uuid, transaction_id: result.transaction_id })
      rescue => e
        Rails.logger.error('Mobile Vet360 account linking failed for user with uuid',
                           { user_uuid: uuid })
        raise e
      ensure
        redis = Redis::Namespace.new(REDIS_CONFIG[:mobile_vets360_account_link_lock][:namespace], redis: Redis.current)
        redis.del(uuid)
      end
    end
  end
end
