# frozen_string_literal: true

require 'active_model'
require 'oj'

module Common
  class RedisModel
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Validations
    include ActiveModel::Serialization

    # rubocop:disable ThreadSafety/ClassAndModuleAttributes
    class_attribute :redis_namespace, instance_writer: false
    class_attribute :redis_ttl, instance_writer: false
    class_attribute :redis_key, instance_writer: false
    class_attribute :computed_fallback, instance_writer: false, default: {}
    # rubocop:enable ThreadSafety/ClassAndModuleAttributes

    class << self
      def redis_store(namespace)
        self.redis_namespace = Redis::Namespace.new(namespace, redis: $redis)
      end

      def redis_ttl(ttl)
        self.redis_ttl = ttl
      end

      def redis_key(field)
        self.redis_key = field.to_s
      end

      def computed_fallbacks(hash = nil)
        if hash
          self.computed_fallback = hash.transform_keys(&:to_sym)
        else
          computed_fallback
        end
      end

      def find(key)
        raw = redis_namespace.get(key)
        return nil if raw.blank?

        attrs = Oj.load(raw)
        new(attrs.merge(redis_key => key))
      end

      def create(attrs)
        new(attrs).tap(&:save)
      end

      def delete(key)
        redis_namespace.del(key)
      end

      delegate :exists?, :keys, to: :redis_namespace
    end

    attr_reader :persisted

    def initialize(attrs = {})
      super(attrs)
      @persisted = false
    end

    def redis_key
      send(self.class.redis_key)
    end

    def save
      return false unless valid?
      return false if redis_key.blank?

      self.class.redis_namespace.set(redis_key, Oj.dump(serializable_hash))
      self.class.redis_namespace.expire(redis_key, self.class.redis_ttl) if self.class.redis_ttl
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
      self.class.redis_namespace.del(redis_key)
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
      value.presence || self.class.computed_fallback[attr_name.to_sym]
    end

    def serializable_hash(*)
      base_hash = super
      computed_hash = self.class.computed_fallback.keys.index_with { |attr| computed(attr) }
      base_hash.merge(computed_hash)
    end
  end
end
