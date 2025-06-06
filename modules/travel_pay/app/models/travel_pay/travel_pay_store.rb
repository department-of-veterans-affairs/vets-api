# frozen_string_literal: true

require 'common/models/redis_store'

module TravelPay
  class TravelPayStore < Common::RedisStore
    redis_store REDIS_CONFIG[:travel_pay_store][:namespace]
    redis_ttl REDIS_CONFIG[:travel_pay_store][:each_ttl]
    redis_key :user_account_id

    attribute :user_account_id, String
    attribute :veis_token, String
    attribute :btsss_token, String
  end
end
