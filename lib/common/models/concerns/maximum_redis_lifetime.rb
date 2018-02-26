# frozen_string_literal: true

require 'common/models/redis_store'

module Common
  module MaximumRedisLifetime
    extend ActiveSupport::Concern

    included do
      unless self < Common::RedisStore
        raise ArgumentError, 'Class composing Common::MaximumRedisLifetime must be a Common::RedisStore'
      end

      extend(ClassMethods)

      validate :within_maximum_ttl
      validates :created_at, presence: true

      after_initialize :set_created_at
    end

    def expire(ttl)
      ttl < maximum_time_remaining ? super(ttl) : super(maximum_time_remaining)
    end

    private

    def maximum_time_remaining
      (@created_at + self.class.maximum_redis_ttl - Time.now.utc).round
    end

    def within_maximum_ttl
      if maximum_time_remaining.negative?
        errors.add(:created_at, "is more than the max of [#{self.class.maximum_redis_ttl}] ago. Session is too old")
      end
    end

    def created_at_exists?
      attributes.any? { |name, _val| name == :created_at }
    end

    def set_created_at
      unless created_at_exists?
        raise ArgumentError, 'Class composing Common::MaximumRedisLifetime must contain a "created_at" attribute'
      end

      @created_at ||= Time.now.utc
    end
  end

  module ClassMethods
    attr_accessor :maximum_redis_ttl

    def redis_maximum_ttl(ttl)
      @maximum_redis_ttl = ttl
    end
  end
end
