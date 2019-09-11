# frozen_string_literal: true

require 'common/models/redis_store'

class StatsDMetric < Common::RedisStore
  redis_store REDIS_CONFIG['statsd_roster']['namespace']
  redis_ttl REDIS_CONFIG['statsd_roster']['each_ttl']
  redis_key :key
  attribute :key

  validates :key, presence: true
end
