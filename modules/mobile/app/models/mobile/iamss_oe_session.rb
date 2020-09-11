# frozen_string_literal: true

require 'sentry_logging'

module Mobile
  class IAMSSOeSession
    include Redis::Objects
    
    REDIS_NAMESPACE = Redis::Namespace.new(REDIS_CONFIG[:iam_ssoe_session][:namespace], redis: Redis.current)
    REDIS_TTL = Redis::Namespace.new(REDIS_CONFIG[:iam_ssoe_session][:each_ttl])
    
    value :token
    value :payload, :expireat => Time.now.utc + REDIS_TTL
    redis_id_field :token
  end
end

Mobile::IAMSSOeSession.redis = Mobile::IAMSSOeSession::REDIS_NAMESPACE
