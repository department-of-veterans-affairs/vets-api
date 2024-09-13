# frozen_string_literal: true

require_relative '../../models/travel_pay/travel_pay_cache'

module TravelPay
  class TokenService
    #
    # returns a hash containing the veis_token & btsss_token
    #
    def get_tokens(current_user)
      cached = cached_by_account_uuid(current_user.account_uuid)
      if cached
        Rails.logger.info('BTSSS tokens retrieved from cache',
                          { request_id: RequestStore.store['request_id'] })
        cached.tokens
      else
        Rails.logger.info('BTSSS tokens not cached, requesting new tokens',
                          { request_id: RequestStore.store['request_id'] })

        veis_token = token_client.request_veis_token
        btsss_token = token_client.request_btsss_token(veis_token, current_user)
        save_tokens!(current_user.account_uuid, { veis_token:, btsss_token: })
        Rails.logger.info('BTSSS tokens saved to cache',
                          { request_id: RequestStore.store['request_id'] })

        { veis_token:, btsss_token: }
      end
    end

    private

    def cached_by_account_uuid(account_uuid)
      TravelPayTokenStore.find(account_uuid)
    end

    def save_tokens!(account_uuid, tokens)
      token_store = TravelPayTokenStore.new(
        account_uuid:,
        tokens:
      )
      token_store.save
    end

    def token_client
      TravelPay::TokenClient.new
    end

    def redis
      @redis ||= Redis::Namespace.new(REDIS_CONFIG[:travel_pay_token_store][:namespace], redis: $redis)
    end
  end
end
