# frozen_string_literal: true

module Common
  class RedisModel
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Validations
    include ActiveModel::Serialization

    # rubocop:disable ThreadSafety/ClassAndModuleAttributes
    class_attribute :namespace, instance_writer: false
    class_attribute :ttl, instance_writer: false
    class_attribute :primary_key, instance_writer: false
    class_attribute :fallbacks, instance_writer: false, default: nil
    # rubocop:enable ThreadSafety/ClassAndModuleAttributes

    class << self
      def redis_store(name)
        self.namespace = Redis::Namespace.new(name, redis: $redis).freeze
      end

      def redis_ttl(seconds)
        self.ttl = seconds
      end

      def redis_key(attr)
        self.primary_key = attr.to_s.freeze
      end

      def computed_fallbacks(hash = nil)
        if hash
          self.fallbacks = hash.transform_keys(&:to_sym).freeze
        else
          self.fallbacks ||= {}.freeze
        end
      end

      def find_by(key)
        raw = namespace.get(key)
        return nil if raw.blank?

        attrs = JSON.parse(raw)

        allowed_keys = attribute_types.keys.map(&:to_s)
        filtered_attrs = attrs.slice(*allowed_keys)

        new(filtered_attrs).tap { |obj| obj.instance_variable_set(:@persisted, true) }
      end

      def find(key)
        find_by(key) || raise(ActiveRecord::RecordNotFound, "Couldn't find #{name} with #{primary_key}=#{key}")
      end

      def create(attrs)
        new(attrs).tap(&:save)
      end

      def create!(attrs)
        new(attrs).tap(&:save!)
      end

      delegate :exists?, :keys, to: :namespace
    end

    attr_reader :persisted

    def initialize(attrs = {})
      super(attrs)
      @persisted = false
    end

    def redis_key_value
      send(self.class.primary_key)
    end

    def save
      return false unless valid?
      return false if redis_key_value.blank?

      begin
        namespace.set(redis_key_value, to_json, ex: self.class.ttl)
        @persisted = true
        true
      rescue => e
        errors.add(:base, e.message)
        false
      end
    end

    def save!
      raise ActiveModel::ValidationError, self unless save
    end

    def update(attrs)
      assign_attributes(attrs)
      save
    end

    def update!(attrs)
      assign_attributes(attrs)
      save!
    end

    def destroy
      deleted = namespace.del(redis_key_value)
      @destroyed = true
      freeze
      deleted
    end

    def destroy!
      deleted = destroy
      raise("Unable to destroy #{self.class.name} with key: #{redis_key_value}") if deleted.zero?

      deleted
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

    def as_json(*)
      self.class.attribute_names.index_with { |attr| public_send(attr) }
    end
  end
end
