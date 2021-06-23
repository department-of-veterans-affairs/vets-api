# frozen_string_literal: true

require 'common/models/concerns/cache_aside'

class OldEmail < Common::RedisStore
  redis_store REDIS_CONFIG[:old_email][:namespace]
  redis_ttl REDIS_CONFIG[:old_email][:each_ttl]
  redis_key :transaction_id

  attribute :transaction_id, String
  attribute :email, String

  validates(:transaction_id, :email, presence: true)
end
