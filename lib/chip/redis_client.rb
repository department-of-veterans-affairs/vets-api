# frozen_string_literal: true

module Chip
  class RedisClient
    attr_reader :redis_namespace, :key

    def self.build(key)
      new(key)
    end

    def initialize(key)
      @redis_namespace = Redis::Namespace.new(namespace, redis: $redis)
      @key = key
    end

    def get
      redis_namespace.get(key)
    end

    def save(token:)
      redis_namespace.set(key, token, ex: ttl)
    end

    def ttl
      @ttl ||= REDIS_CONFIG[:chip][:each_ttl]
    end

    def namespace
      @namespace ||= REDIS_CONFIG[:chip][:namespace]
    end
  end
end
