# frozen_string_literal: true

require 'common/models/redis_store'

module VAOS
  class SessionStore < Common::RedisStore
    redis_store REDIS_CONFIG[:va_mobile_session][:namespace]
    redis_ttl REDIS_CONFIG[:va_mobile_session][:each_ttl]
    redis_key :user_account_id

    attribute :user_account_id, String
    attribute :token, String
  end
end
