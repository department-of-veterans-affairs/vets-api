# frozen_string_literal: true

module MDOT
  class Token < Common::RedisStore
    redis_store REDIS_CONFIG[:mdot][:namespace]
    redis_ttl REDIS_CONFIG[:mdot][:each_ttl]
    redis_key :uuid

    attribute :uuid
    attribute :token

    def self.build(redis_key)
      new(Hash[@redis_namespace_key, redis_key])
    end
  end
end
