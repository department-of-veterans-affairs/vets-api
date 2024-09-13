# frozen_string_literal: true

require 'common/models/redis_store'
require 'common/models/concerns/cache_aside'

module TravelPay
  class TravelPayTokenStore < Common::RedisStore
    # include Common::CacheAside
    redis_store REDIS_CONFIG[:travel_pay_token_store][:namespace]
    redis_ttl REDIS_CONFIG[:travel_pay_token_store][:each_ttl]
    redis_key :account_uuid

    attribute :account_uuid, String
    attribute :tokens, Hash
  end
end
