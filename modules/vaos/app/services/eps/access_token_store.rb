# frozen_string_literal: true

require 'common/models/redis_store'

module Eps
  class AccessTokenStore < Common::RedisStore
    redis_store REDIS_CONFIG[:eps_access_token][:namespace]
    redis_ttl REDIS_CONFIG[:eps_access_token][:each_ttl]
    redis_key :token_type

    attribute :token_type
    attribute :access_token
  end
end
