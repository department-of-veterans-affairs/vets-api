# frozen_string_literal: true

require_relative '../../models/travel_pay/travel_pay_store'

module TravelPay
  class TokenService
    #
    # returns a hash containing the veis_token & btsss_token
    #
    def get_tokens(current_user)
      cached = cached_by_account_uuid(current_user.account_uuid)
      # Check that btsss token exists, if so, veis token must also be present
      if cached&.btsss_token
        Rails.logger.info('BTSSS tokens retrieved from cache',
                          { request_id: RequestStore.store['request_id'] })
        cached.tokens
      elsif cached&.veis_token
        # if the btsss token isn't cached, check whether or not the veis token is there
        Rails.logger.info('BTSSS token not cached, requesting new token with existing VEIS token',
                          { request_id: RequestStore.store['request_id'] })
        request_btsss_token(cached.tokens[:veis_token], current_user)
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
      token_store = TravelPayStore.new(
        account_uuid:,
        tokens:
      )
      token_store.save
    end

    def request_new_tokens(current_user)
      begin
        veis_token = token_client.request_veis_token
      rescue Faraday::Error => e
        TravelPay::ServiceError.raise_mapped_error(e)
      end
      request_btsss_token(veis_token, current_user)
    end

    def request_btsss_token(veis_token, current_user)
      begin
        btsss_token = token_client.request_btsss_token(veis_token, current_user)
      rescue Faraday::Error => e
        Rails.logger.info('BTSSS token could not be retrieved, saving VEIS token only',
                          { request_id: RequestStore.store['request_id'] })
        save_tokens!(current_user.account_uuid, { veis_token:, btsss_token: nil })

        TravelPay::ServiceError.raise_mapped_error(e)
      end

      save_tokens!(current_user.account_uuid, { veis_token:, btsss_token: })
      Rails.logger.info('BTSSS tokens saved to cache',
                        { request_id: RequestStore.store['request_id'] })

      { veis_token:, btsss_token: }
    end

    def token_client
      TravelPay::TokenClient.new
    end

    def redis
      @redis ||= Redis::Namespace.new(REDIS_CONFIG[:travel_pay_store][:namespace], redis: $redis)
    end
  end
end
