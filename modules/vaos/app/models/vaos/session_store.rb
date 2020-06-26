# frozen_string_literal: true

module VAOS
  class SessionStore < Common::RedisStore
    redis_store REDIS_CONFIG[:va_mobile_session][:namespace]
    redis_ttl REDIS_CONFIG[:va_mobile_session][:each_ttl]
    redis_key :account_uuid

    attribute :account_uuid, String
    attribute :token, String
  end
end
