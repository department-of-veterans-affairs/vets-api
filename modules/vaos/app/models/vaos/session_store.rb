# frozen_string_literal: true

module VAOS
  class SessionStore < Common::RedisStore
    redis_store REDIS_CONFIG['va_mobile_session']['namespace']
    redis_ttl REDIS_CONFIG['va_mobile_session']['each_ttl']
    redis_key :user_uuid

    attribute :user_uuid, String
    attribute :token, String
  end
end
