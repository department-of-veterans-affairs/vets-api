# frozen_string_literal: true

module MDOT::V2
  class Session < Common::RedisStore
    redis_store REDIS_CONFIG[:mdot_v2][:namespace]
    redis_ttl REDIS_CONFIG[:mdot_v2][:each_ttl]
    redis_key :uuid

    validates :uuid, presence: true
    validates :token, presence: true

    attribute :uuid
    attribute :token
  end
end
