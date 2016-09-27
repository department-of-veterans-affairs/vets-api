# frozen_string_literal: true
class RedisStore
  extend ActiveModel::Naming
  extend ActiveModel::Callbacks
  define_model_callbacks :initialize, only: :after

  include ActiveModel::Serialization
  include ActiveModel::Validations
  include Virtus.model
  REDIS_STORE = Redis.current

  def initialize(attributes = {}, persisted = false)
    super(attributes)
    @persisted = persisted
    run_callbacks :initialize
  end

  def self.find(redis_key = nil)
    response = REDIS_STORE.get(redis_key)
    return nil unless response
    attributes = Oj.load(response).with_indifferent_access
    return nil if attributes.blank?
    object = new(attributes, true)
    if object.valid?
      object
    else
      REDIS_STORE.del(redis_key)
      nil
    end
  end

  def self.exists?(redis_key = nil)
    REDIS_STORE.exists(redis_key)
  end

  def self.create(attributes)
    new(attributes).save
  end

  def save
    return false unless valid?
    REDIS_STORE.set(redis_key, Oj.dump(attributes, mode: :compat))
    REDIS_STORE.expire(redis_key, self.class::DEFAULT_TTL) if defined? self.class::DEFAULT_TTL
    @persisted = true
  end

  def update(attributes_hash)
    self.attributes = attributes_hash
    save
  end

  def destroy
    REDIS_STORE.del(redis_key)
  end

  def ttl
    REDIS_STORE.ttl(redis_key)
  end

  def persisted?
    @persisted == true
  end
end
