# frozen_string_literal: true

module Common
  class RedisModel
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Validations
    include ActiveModel::Serialization

    class_attribute :namespace, instance_writer: false
    class_attribute :ttl, instance_writer: false
    class_attribute :key_attribute, instance_writer: false
    class_attribute :fallbacks, instance_writer: false, default: {}

    class << self
      def redis_store(name)
        self.namespace = Redis::Namespace.new(name, redis: $redis)
      end

      def redis_ttl(seconds)
        self.ttl = seconds
      end

      def redis_key(attr)
        self.key_attribute = attr.to_s
      end

      def computed_fallbacks(hash = nil)
        hash ? self.fallbacks = hash.transform_keys(&:to_sym) : fallbacks
      end

      def find(key)
        raw = namespace.get(key)
        return nil if raw.blank?

        attrs = JSON.parse(raw)
        new(attrs.merge(key_attribute => key))
      end

      def create(attrs)
        new(attrs).tap(&:save)
      end

      def delete(key)
        namespace.del(key)
      end

      delegate :exists?, :keys, to: :namespace
    end

    attr_reader :persisted

    def initialize(attrs = {})
      super(attrs)
      @persisted = false
    end

    def redis_key_value
      send(self.class.key_attribute)
    end

    def save
      return false unless valid?
      return false if redis_key_value.blank?

      namespace.set(redis_key_value, JSON.dump(serializable_hash))
      namespace.expire(redis_key_value, ttl) if ttl
      @persisted = true
    end

    def save!
      raise ActiveModel::ValidationError, self unless save
    end

    def update(attrs)
      assign_attributes(attrs)
      save
    end

    def destroy
      namespace.del(redis_key_value)
      @destroyed = true
      freeze
    end

    def persisted?
      !!@persisted
    end

    def destroyed?
      !!@destroyed
    end

    def computed(attr_name)
      value = public_send(attr_name)
      value.presence || self.class.fallbacks[attr_name.to_sym]
    end
  end
end
