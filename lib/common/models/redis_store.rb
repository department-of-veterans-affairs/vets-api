# frozen_string_literal: true
module Common
  class RedisStore
    extend ActiveModel::Naming
    extend ActiveModel::Callbacks

    include ActiveModel::Serialization
    include ActiveModel::Validations
    include Virtus.model(nullify_blank: true)

    define_model_callbacks :initialize, only: :after

    REQ_CLASS_INSTANCE_VARS = %i(redis_namespace redis_namespace_key).freeze

    class << self
      attr_accessor :redis_namespace, :redis_namespace_ttl, :redis_namespace_key
    end

    def self.redis_store(namespace)
      @redis_namespace = Redis::Namespace.new(namespace, redis: Redis.current)
    end
    delegate :redis_namespace, to: 'self.class'

    def self.redis_ttl(ttl)
      @redis_namespace_ttl = ttl
    end
    delegate :redis_namespace_ttl, to: 'self.class'

    def self.redis_key(key)
      @redis_namespace_key = key
    end
    delegate :redis_namespace_key, to: 'self.class'

    def initialize(attributes = {}, persisted = false)
      undefined = REQ_CLASS_INSTANCE_VARS.select { |class_var| send(class_var).nil? }
      raise NoMethodError, "Required class methods #{undefined.join(', ')} are not defined" if undefined.any?
      super(attributes)
      @persisted = persisted
      run_callbacks :initialize
    end

    def self.find(redis_key = nil)
      response = redis_namespace.get(redis_key)
      return nil unless response
      attributes = Oj.load(response)
      return nil if attributes.blank?
      object = new(attributes, true)
      if object.valid?
        object
      else
        redis_namespace.del(redis_key)
        nil
      end
    end

    def self.exists?(redis_key = nil)
      redis_namespace.exists(redis_key)
    end

    def self.create(attributes)
      instance = new(attributes)
      instance.save
      instance
    end

    def save
      return false unless valid?
      redis_namespace.set(attributes[redis_namespace_key], Oj.dump(attributes))
      if defined? redis_namespace_ttl
        redis_namespace.expire(
          attributes[redis_namespace_key], redis_namespace_ttl
        )
      end
      @persisted = true
    end

    def save!
      raise Common::Exceptions::ValidationErrors, self unless save
    end

    def update(attributes_hash)
      self.attributes = attributes_hash
      save
    end

    def destroy
      redis_namespace.del(attributes[redis_namespace_key])
    end

    def ttl
      redis_namespace.ttl(attributes[redis_namespace_key])
    end

    def persisted?
      @persisted
    end
  end
end
