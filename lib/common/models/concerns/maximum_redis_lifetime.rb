# frozen_string_literal: true

require 'common/models/redis_store'

module Common
  module MaximumRedisLifetime
    extend ActiveSupport::Concern

    included do
      unless self < Common::RedisStore
        raise ArgumentError, 'Class composing Common::MaximumRedisLifetime must be a Common::RedisStore'
      end

      validate :within_maximum_ttl
    end

    MAX_SESSION_LIFETIME = 12.hours

    def expire(ttl)
      (ttl < maximum_time_remaining) ? super(ttl) : super(maximum_time_remaining)
    end

    def maximum_time_remaining
      (@created_at + MAX_SESSION_LIFETIME - Time.now.utc).round
    end

    def within_maximum_ttl
      if maximum_time_remaining.negative?
        errors.add(:created_at, "is more than the max of [#{MAX_SESSION_LIFETIME}] ago. Session is too old")
      end
    end
  end
end