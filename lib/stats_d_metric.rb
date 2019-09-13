# frozen_string_literal: true

require 'common/models/redis_store'

# This model is responsible for keeping track of the dynamic metrics that get incremented by
# /lib/common/client/concerns/monitoring.rb , for the purpose of initializing them to zero at
# vets-api initialization time
#
# When a metric is incremented by /lib/common/client/concerns/monitoring.rb, we save that metric
# name as a StatsDMetric, e.g. in Redis:
#
# {"gi_bill_submit.total" => {}}
#
# In the event that the metric name already exists, the Redis TTL is refreshed. At vets-api
# initialization time, this list is read from Redis and initialized to zero
# (e.g. StatsD.increment("<NAME FROM REDIS>", 0)). For metrics that are not refreshed,
# they expire from Redis and will not be initialized to 0 on future `vets-api` initializations.
class StatsDMetric < Common::RedisStore
  redis_store REDIS_CONFIG['statsd_roster']['namespace']
  redis_ttl REDIS_CONFIG['statsd_roster']['each_ttl']
  redis_key :key
  attribute :key

  validates :key, presence: true
end
