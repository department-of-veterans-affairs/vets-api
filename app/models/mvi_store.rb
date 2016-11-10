# frozen_string_literal: true
require 'digest'
require 'common/models/redis_store'

class MviStore < Common::RedisStore
  redis_store REDIS_CONFIG['mvi_store']['namespace']
  redis_ttl REDIS_CONFIG['mvi_store']['each_ttl']
  redis_key :message_hash

  attribute :message_hash
  attribute :response
end
