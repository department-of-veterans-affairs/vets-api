# frozen_string_literal: true

module MDOT
  class Token < Common::RedisStore
    redis_store REDIS_CONFIG[:mdot][:namespace]
    redis_ttl REDIS_CONFIG[:mdot][:each_ttl]
    redis_key :uuid

    validates :uuid, presence: true

    attribute :uuid
    attribute :token
  end
end

# JSON.parse( $redis.get("mdot:#{current_user.uuid}") ) =>
# { ":uuid"=>"[REDACTED]", ":token"=>"[REDACTED]" }
