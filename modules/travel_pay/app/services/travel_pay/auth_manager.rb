# frozen_string_literal: true

module TravelPay
  class AuthManager
    def initialize(client_number, current_user)
      @user = current_user
      @client = TravelPay::TokenClient.new(client_number)
    end

    #
    # returns a hash containing the veis_token & btsss_token
    #
    def authorize
      cached = TravelPayStore.find(@user.account_uuid)
      if cached
        Rails.logger.info('BTSSS tokens retrieved from cache',
                          { request_id: RequestStore.store['request_id'] })
        { veis_token: cached.veis_token, btsss_token: cached.btsss_token }
      else
        Rails.logger.info('BTSSS tokens not cached, requesting new tokens',
                          { request_id: RequestStore.store['request_id'] })

        request_new_tokens
      end
    end

    private

    def request_new_tokens
      veis_token = @client.request_veis_token
      btsss_token = @client.request_btsss_token(veis_token, @user)
      if btsss_token
        save_tokens!(@user.account_uuid, { veis_token:, btsss_token: })
        Rails.logger.info('BTSSS tokens saved to cache',
                          { request_id: RequestStore.store['request_id'] })
        { veis_token:, btsss_token: }
      end
    end

    def save_tokens!(account_uuid, tokens)
      token_record = TravelPayStore.new(
        account_uuid:,
        veis_token: tokens[:veis_token],
        btsss_token: tokens[:btsss_token]
      )
      token_record.save
    end

    def redis
      @redis ||= Redis::Namespace.new(REDIS_CONFIG[:travel_pay_store][:namespace], redis: $redis)
    end
  end
end
