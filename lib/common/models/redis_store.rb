# frozen_string_literal: true

module Common
  class RedisStore
    extend ActiveModel::Naming
    extend ActiveModel::Callbacks

    include ActiveModel::Serialization
    include ActiveModel::Validations
    include Virtus.model(nullify_blank: true)

    define_model_callbacks :initialize, only: :after

    REQ_CLASS_INSTANCE_VARS = %i[redis_namespace redis_namespace_key].freeze

    class << self
      attr_reader :redis_namespace_ttl, :redis_namespace, :redis_namespace_key
    end

    def self.redis_store(namespace)
      @redis_namespace = Redis::Namespace.new(namespace, redis: $redis)
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

      begin
        super(attributes)
      rescue NoMethodError
        Rails.logger.error("attributes failure: #{attributes}")
        raise
      end

      @persisted = persisted
      run_callbacks :initialize
    end

    def self.find(redis_key = nil)
      response = redis_namespace.get(redis_key)
      return nil unless response

      attributes = Oj.load(response)
      return nil if attributes.blank?

      unless attributes.is_a?(Hash)
        Rails.logger.info("redis_namespace: #{redis_namespace.inspect} - response: #{response}
                            - oj parsed attributes: #{attributes} redis_key: #{redis_key}")

        nil if redis_key.blank? # Case where session[:token] is empty and response returns 1
      end

      object = new(attributes, true)
      if object.valid?
        object
      else
        redis_namespace.del(redis_key)
        nil
      end
    end

    def self.find_or_build(redis_key)
      find(redis_key) || new({ @redis_namespace_key => redis_key })
    end

    def self.pop(redis_key = nil)
      object = find(redis_key)
      delete(redis_key) && object if object
    end

    def self.exists?(redis_key = nil)
      redis_namespace.exists?(redis_key)
    end

    def self.create(attributes)
      instance = new(attributes)
      instance.save
      instance
    end

    def self.keys
      redis_namespace.keys
    end

    def self.delete(redis_key = nil)
      redis_namespace.del(redis_key)
    end

    def save
      return false unless valid?

      redis_namespace.set(attributes[redis_namespace_key], Oj.dump(attributes))
      expire(redis_namespace_ttl) if defined? redis_namespace_ttl
      @persisted = true
    end

    def update!(attributes_hash)
      self.attributes = attributes_hash
      save!
    end

    def save!
      raise Common::Exceptions::ValidationErrors, self unless save
    end

    def update(attributes_hash)
      self.attributes = attributes_hash
      save
    end

    # The instance should be frozen once destroyed, since object can no longer be persisted.
    # See also: ActiveRecord::Persistence#destroy
    def destroy
      count = redis_namespace.del(attributes[redis_namespace_key])
      @destroyed = true
      freeze
      count
    end

    def initialize_dup(other)
      initialize_copy(other)
      @destroyed = false
    end

    def ttl
      redis_namespace.ttl(attributes[redis_namespace_key])
    end

    def expire(ttl)
      redis_namespace.expire(attributes[redis_namespace_key], ttl)
    end

    def persisted?
      @persisted
    end

    def destroyed?
      @destroyed == true
    end
  end
end
