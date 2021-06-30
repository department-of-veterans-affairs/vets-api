# frozen_string_literal: true

require 'common/models/concerns/cache_aside'

class TransactionNotification < Common::RedisStore
  redis_store REDIS_CONFIG[:transaction_notification][:namespace]
  redis_ttl REDIS_CONFIG[:transaction_notification][:each_ttl]
  redis_key :transaction_id

  attribute :transaction_id, String

  validates(:transaction_id, presence: true)
end
