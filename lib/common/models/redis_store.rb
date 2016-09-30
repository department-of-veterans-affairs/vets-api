# frozen_string_literal: true
module Common
  class RedisStore
    extend ActiveModel::Naming
    extend ActiveModel::Callbacks

    include ActiveModel::Serialization
    include ActiveModel::Validations
    include Virtus.model

    define_model_callbacks :initialize, only: :after

    class << self
      attr_accessor :redis, :ttl
    end

    def self.redis_store(namespace)
      @redis ||= Redis::Namespace.new(namespace, redis: Redis.current)
    end

    def self.default_ttl(ttl)
      @ttl ||= ttl
    end

    def initialize(attributes = {}, persisted = false)
      super(attributes)
      @persisted = persisted
      run_callbacks :initialize
    end

    def self.find(redis_key = nil)
      response = redis.get(redis_key)
      return nil unless response
      attributes = Oj.load(response)
      return nil if attributes.blank?
      object = new(attributes, true)
      if object.valid?
        object
      else
        redis.del(redis_key)
        nil
      end
    end

    def self.exists?(redis_key = nil)
      redis.exists(redis_key)
    end

    def self.create(attributes)
      new(attributes).save
    end

    def save
      return false unless valid?
      self.class.redis.set(redis_key, Oj.dump(attributes))
      self.class.redis.expire(redis_key, self.class.ttl) if defined? self.class.ttl
      @persisted = true
    end

    def update(attributes_hash)
      self.attributes = attributes_hash
      save
    end

    def destroy
      self.class.redis.del(redis_key)
    end

    def ttl
      self.class.redis.ttl(redis_key)
    end

    def persisted?
      @persisted
    end
  end
end
