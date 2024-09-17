# frozen_string_literal: true

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
        { veis_token: cached.veis_token, btsss_token: cached.btsss_token }
      else
        Rails.logger.info('BTSSS tokens not cached, requesting new tokens',
                          { request_id: RequestStore.store['request_id'] })
        request_new_tokens(current_user)
      end
    end

    private

    def cached_by_account_uuid(account_uuid)
      TravelPayStore.find(account_uuid)
    end

    def save_tokens!(account_uuid, tokens)
      token_record = TravelPayStore.new(
        account_uuid:,
        veis_token: tokens[:veis_token],
        btsss_token: tokens[:btsss_token]
      )
      token_record.save
    end

    def request_new_tokens(current_user)
      veis_token = token_client.request_veis_token
      btsss_token = token_client.request_btsss_token(veis_token, current_user)
      if btsss_token
        save_tokens!(current_user.account_uuid, { veis_token:, btsss_token: })
        Rails.logger.info('BTSSS tokens saved to cache',
                          { request_id: RequestStore.store['request_id'] })
        { veis_token:, btsss_token: }
      end
    end

    def token_client
      TravelPay::TokenClient.new
    end

    def redis
      @redis ||= Redis::Namespace.new(REDIS_CONFIG[:travel_pay_store][:namespace], redis: $redis)
    end
  end
end
