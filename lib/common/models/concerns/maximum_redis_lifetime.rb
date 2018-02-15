# frozen_string_literal: true

require 'common/models/redis_store'

module Common
  module MaximumRedisLifetime
    extend ActiveSupport::Concern

    included do
      unless self < Common::RedisStore
        raise ArgumentError, 'Class composing Common::MaximumRedisLifetime must be a Common::RedisStore'
      end

      self.extend(ClassMethods)

      validate :within_maximum_ttl
    end

    def expire(ttl)
      (ttl < maximum_time_remaining) ? super(ttl) : super(maximum_time_remaining)
    end

    def maximum_time_remaining
      (@created_at + self.class.maximum_redis_ttl - Time.now.utc).round
    end

    def within_maximum_ttl
      if maximum_time_remaining.negative?
        errors.add(:created_at, "is more than the max of [#{self.class.maximum_redis_ttl}] ago. Session is too old")
      end
    end
  end

  module ClassMethods
    attr_accessor :maximum_redis_ttl

    def redis_maximum_ttl(ttl)
      @maximum_redis_ttl = ttl
    end
  end
end